import os.path

from . import consts
from .utils import api_wrap, request


def download_beatmap(ctx):
    """Download a .osu file."""
    if not ctx.beatmap:
        return None
    osu_path = "/tmp/%d.osu" % ctx.beatmap.beatmap_id
    if os.path.isfile(osu_path):
        return osu_path

    text = request("%s/osu/%d" % (consts.osu_url, ctx.beatmap.beatmap_id))
    if not text:
        return None
    with open(osu_path, "w") as f:
        f.write(text)

    return osu_path


def mapper_id(ctx):
    """Get the mapper ID of a beatmap."""
    text = request("%s/b/%d" % (consts.osu_url, ctx.beatmap.beatmap_id))
    if not text:
        return None

    match = consts.mapper_id_re.search(text)
    if not match:
        print("No mapper ID match found")
        return None
    return int(match.group(1))


def playstyle(ctx):
    """Try to find the player's playstyle on their userpage."""
    if not ctx.player:
        print("Player is missing: Skipping playstyle")
        return None

    website = request("%s/u/%d" % (consts.osu_url, ctx.player.user_id))
    if not website:
        return None

    mouse = "M" if consts.playstyle_m_re.search(website) else None
    keyboard = "KB" if consts.playstyle_kb_re.search(website) else None
    tablet = "TB" if consts.playstyle_tb_re.search(website) else None
    touch = "TD" if consts.playstyle_td_re.search(website) else None

    joined = "+".join(filter(bool, [mouse, keyboard, tablet, touch]))

    return None if not joined else joined


def max_combo(ctx):
    """Try to find the max combo of a beatmap."""
    if ctx.beatmap.max_combo is not None and ctx.beatmap.mode.value == ctx.mode:  # noqa
        return ctx.beatmap.max_combo

    combo = api_max_combo(ctx)
    if combo is not None:
        return combo

    # Taiko is the only mode where the number of hitobject lines in
    # the .osu file corresponds exactly to the max combo.
    if ctx.mode == consts.taiko:
        nobjs = map_objects(ctx)
        if nobjs is not None:
            return nobjs[0] + nobjs[1]

    if ctx.mode in [consts.taiko, consts.ctb]:
        combo = web_max_combo(ctx)  # This might not be accurate for mania.
        if combo is not None:
            return combo

    print("Max combo could not be found")
    return None


def api_max_combo(ctx):
    """Try to find the max combo from a score with the "perfect" bit set."""
    scores = api_wrap(
        consts.osu_api.get_scores,
        ctx.beatmap.beatmap_id,
        mode=consts.int2osuapimode[ctx.mode],
        limit=100,
    )

    for score in scores:
        if score.perfect:
            return int(score.maxcombo)

    return None


def web_max_combo(ctx):
    """Try to find the max combo from the top rank on the leaderboard."""
    # TODO: We could look at all the scores on the leaderboard.
    text = request("%s/b/%d" % (consts.osu_url, ctx.beatmap.beatmap_id))
    if not text:
        return None

    if ctx.mode == consts.mania:
        misses_re = consts.mania_misses_re
    else:
        misses_re = consts.misses_re

    match = consts.combo_re.search(text)
    if not match:
        print("No combo match")
        return None
    combo = match.group(1)
    match = misses_re.search(text)
    if not match:
        print("No misses match")
        return None

    return int(combo) if match.group(1) == "0" else None


def map_objects(ctx):
    """Get the number of regular hitobjects and sliders in a map, or None."""
    path = download_beatmap(ctx)
    if path is None:
        return None
    with open(path) as f:
        lines = f.read().split()

    for i, line in enumerate(lines):
        if "[HitObjects]" in line:
            break
    else:
        print("No hit objects section")
        return None

    regulars, sliders = 0, 0
    for line in lines[(i+1):]:
        if "|" in line:
            sliders += 1
        elif line:
            regulars += 1

    return regulars, sliders

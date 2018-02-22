import os.path

from . import consts
from .utils import request, s3_download, s3_upload, safe_call


def download_beatmap(ctx):
    """Download a .osu file."""
    if not ctx.beatmap:
        return None

    osu_path = "/tmp/%s.osu" % ctx.beatmap.file_md5
    if os.path.isfile(osu_path):
        return osu_path

    s3_key = "osu/%s.osu" % ctx.beatmap.file_md5
    if s3_download(s3_key, osu_path):
        return osu_path

    # TODO: This request sometimes fails for no apparent reason.
    text = request("%s/osu/%d" % (consts.osu_url, ctx.beatmap.beatmap_id))
    if not text:
        return None
    text = consts.osu_file_begin_re.sub("osu file format", text)

    with open(osu_path, "w") as f:
        f.write(text)

    s3_upload(s3_key, text)

    return osu_path


def mapper_id(ctx):
    """Get the mapper ID of a beatmap."""
    text = request("%s/b/%d" % (consts.osu_url, ctx.beatmap.beatmap_id))
    if not text:
        return None

    match = consts.mapper_id_re.search(text)
    if not match:
        return None
    return int(match.group(1))


def player_old_username(ctx):
    """Get a player's old username from their profile, if applicable."""
    if not ctx.player:
        return None

    text = request("%s/u/%d" % (consts.osu_url, ctx.player.user_id))
    if not text:
        return None

    match = consts.old_username_re.search(text)
    return match.group(1) if match else None


def playstyle(ctx):
    """Try to find the player's playstyle on their userpage."""
    if not ctx.player:
        return None

    website = request("%s/u/%d" % (consts.osu_url, ctx.player.user_id))
    if not website:
        return None

    mouse = "M" if consts.playstyle_m_re.search(website) else None
    tablet = "TB" if consts.playstyle_tb_re.search(website) else None
    touch = "TD" if consts.playstyle_td_re.search(website) else None
    keyboard = "KB" if consts.playstyle_kb_re.search(website) else None

    joined = "+".join(filter(bool, [mouse, tablet, touch, keyboard]))

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

    return None


def api_max_combo(ctx):
    """Try to find the max combo from a score with the "perfect" bit set."""
    scores = safe_call(
        consts.osu_api.get_scores,
        ctx.beatmap.beatmap_id,
        mode=consts.int2osuapimode.get(ctx.mode),
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
        return None
    combo = match.group(1)
    match = misses_re.search(text)
    if not match:
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
        return None

    regulars, sliders = 0, 0
    for line in lines[(i+1):]:
        if "|" in line:
            sliders += 1
        elif line:
            regulars += 1

    return regulars, sliders

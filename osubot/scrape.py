import os.path
import requests

from . import consts
from .utils import api_wrap, safe_call


def download_beatmap(ctx):
    """Download a .osu file."""
    if not ctx.beatmap:
        return None
    osu_path = "/tmp/%d.osu" % ctx.beatmap.beatmap_id
    if os.path.isfile(osu_path):
        return osu_path

    resp = safe_call(
        requests.get,
        "%s/osu/%d" % (consts.osu_url, ctx.beatmap.beatmap_id),
        alt=None,
    )
    if resp is None:
        return None
    if resp.status_code != 200:
        print("Downloading .osu file returned %d" % resp.status_code)
        return None
    with open(osu_path, "w") as f:
        f.write(resp.text)

    return osu_path


def mapper_id(ctx):
    """Get the mapper ID of a beatmap."""
    resp = safe_call(
        requests.get,
        "%s/b/%d" % (consts.osu_url, ctx.beatmap.beatmap_id),
        alt=None,
    )
    if resp is None:
        return None
    if resp.status_code != 200:
        print("Request for beatmap web page returned %d" % resp.status_code)
        return None
    if "Creator" not in resp.text:
        print("No 'Creator' field in response text")
        return None

    # For some reason the regex only matches on a substring of the HTML.
    idx = resp.text.index("Creator:")
    match = consts.mapper_id_re.match(resp.text[idx:idx+100])
    if not match:
        print("No mapper ID match found")
        return None
    return match.group(1)


def max_combo(ctx):
    """Try to find the max combo of a beatmap."""
    if ctx.beatmap.max_combo is not None:
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
    resp = safe_call(
        requests.get,
        "%s/b/%d" % (consts.osu_url, ctx.beatmap.beatmap_id),
        alt=None,
    )
    if resp is None:
        return None
    if resp.status_code != 200:
        print("Request for website returned %d" % resp.status_code)
        return None

    if ctx.mode == consts.mania:
        misses_anchor = consts.mania_misses_anchor
        misses_re = consts.mania_misses_re
    else:
        misses_anchor = consts.misses_anchor
        misses_re = consts.misses_re

    if consts.combo_anchor not in resp.text:
        print("Combo anchor not found")
        return None
    idx = resp.text.index(consts.combo_anchor)
    match = consts.combo_re.match(resp.text[idx:idx+100])
    if not match:
        print("No combo match")
        return None
    if misses_anchor not in resp.text:
        print("Misses anchor not found")
        return None
    combo = match.group(1)
    idx = resp.text.index(misses_anchor)
    match = misses_re.match(resp.text[idx:idx+100])
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

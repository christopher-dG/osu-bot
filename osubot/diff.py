import subprocess
import json

from . import consts, scrape
from .utils import combine_mods


def diff_vals(ctx, modded=True):
    """Get the difficulty values of a map."""
    if not ctx.beatmap:
        return None
    if modded and ctx.mode not in [consts.std, consts.taiko]:
        return None
    return (diff_modded if modded else diff_nomod)(ctx)


def diff_nomod(ctx):
    """Get the unmodded difficulty values of a map."""
    return {
        "cs": ctx.beatmap.diff_size,
        "ar": ctx.beatmap.diff_approach,
        "od": ctx.beatmap.diff_overall,
        "hp": ctx.beatmap.diff_drain,
        "sr": ctx.beatmap.difficultyrating,
        "bpm": ctx.beatmap.bpm,
        "length": ctx.beatmap.total_length,
    }


def diff_modded(ctx):
    """Get the modded difficulty values of a map."""
    if ctx.mode not in [consts.std, consts.taiko] or ctx.mods == consts.nomod:
        return None

    text = scrape.download_beatmap(ctx)
    if text is None:
        return None

    ar = ctx.beatmap.diff_approach
    taiko = "-taiko" if ctx.mode == consts.taiko else ""
    mods = combine_mods(ctx.mods)

    cmd = "echo %s | %s - ar%d %s %s -ojson" % \
          (text, consts.oppai_bin, ar, mods, taiko)
    try:
        out = subprocess.check_output(cmd, shell=True)
    except Exception as e:
        print("oppai command '%s' failed: %s" % (cmd, e))
        return None

    try:
        d = json.loads(out)
    except Exception as e:
        print("Converting oppai output to JSON failed: %s" % e)
        return None

    if ctx.mods | ctx.mods2int["DT"]:  # This catches NC too.
        scalar = 1.5
    elif ctx.mods | ctx.mods2int["HR"]:
        scalar = 1.3333
    else:
        scalar = 1

    length = round(ctx.beatmap.total_length / scalar)
    bpm = ctx.beatmap.bpm * scalar

    return {
        "cs": d["cs"],
        "ar": d["ar"],
        "od": d["od"],
        "hp": d["hp"],
        "sr": d["stars"],
        "bpm": bpm,
        "length": length,
    }

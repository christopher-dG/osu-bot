import json
import os
import subprocess

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

    path = scrape.download_beatmap(ctx)
    if path is None:
        return None

    ar = ctx.beatmap.diff_approach
    cmd = [consts.oppai_bin, path, "ar%d" % ar, "-ojson"]
    if ctx.mods != consts.nomod:
        cmd.append(combine_mods(ctx.mods))
    if ctx.mode == consts.taiko:
        cmd.append("-taiko")
    try:
        out = subprocess.check_output(cmd)
    except Exception as e:
        print("oppai command '%s' failed: %s" % (cmd, e))
        os.remove(path)
        return None

    try:
        d = json.loads(out)
    except Exception as e:
        print("Converting oppai output to JSON failed: %s" % e)
        return None

    if ctx.mods & consts.mods2int["DT"]:  # This catches NC too.
        scalar = 1.5
    elif ctx.mods & consts.mods2int["HT"]:
        scalar = 0.75
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

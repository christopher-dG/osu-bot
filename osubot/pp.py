import catch_the_pp
import json
import os
import subprocess

from . import consts, scrape
from .utils import combine_mods


def pp_val(ctx, acc, modded=True):
    """Get pp earned for a play with given acc."""
    if ctx.mode is None:
        return None

    return {
        consts.std: std_pp,
        consts.taiko: taiko_pp,
        consts.ctb: ctb_pp,
        consts.mania: mania_pp,
    }[ctx.mode](ctx, acc, modded=modded)


def std_pp(ctx, acc, modded=True):
    """Get pp for a standard map."""
    return oppai_pp(ctx, acc, modded=modded)


def taiko_pp(ctx, acc, modded=True):
    """Get pp for a Taiko map."""
    return oppai_pp(ctx, acc, modded=modded, taiko=True)


def ctb_pp(ctx, acc, modded=True):
    """Get pp for a CTB play."""
    if not ctx.beatmap:
        return None

    path = scrape.download_beatmap(ctx)
    if path is None:
        return None

    # I don't know how stable catch_the_pp is so check for errors everywhere.
    try:
        beatmap = catch_the_pp.osu_parser.beatmap.Beatmap(path)
    except Exception as e:
        print("CTB beatmap parsing error: %s" % e)
        return None

    mods = ctx.mods if modded else consts.nomod
    try:
        diff = catch_the_pp.osu.ctb.difficulty.Difficulty(beatmap, mods)
    except Exception as e:
        print("CTB difficulty calculation error: %s" % e)
        return None

    try:
        return catch_the_pp.ppCalc.calculate_pp(
            diff,
            acc / 100,  # acc is passed as a percentage, we want 0-1.
            beatmap.max_combo,
            0,
        )
    except Exception as e:
        print("CTB pp calculation error: %s" % e)
        return None


def mania_pp(ctx, acc, modded=True, score=None):
    """Get pp for a mania map. This is not guaranteed to be accurate."""
    if modded:
        return None  # TODO: semyon422/omppc or wifipiano2@osufx/lets.
    nobjs = scrape.map_objects(ctx)
    if nobjs is None:
        return None
    nobjs = nobjs[0] + nobjs[1]

    # TODO: Improve score approximation.
    if score is None:
        if acc < 94:
            score = 750000
        elif acc < 96:
            score = 850000
        elif acc < 98.5:
            score = 900000
        elif acc < 99.5:
            score = 950000
        else:
            score = 980000

    sr = ctx.beatmap.difficultyrating
    od = ctx.beatmap.diff_overall
    acc /= 100

    # Disclaimer: I did not write this.
    f = 64 - 3 * od
    k = 2.5 * pow((150 / f) * pow(acc, 16), 1.8) * min(1.15, pow(nobjs / 1500, 0.3))
    x = (pow(5 * max(1, sr / 0.0825) - 4, 3) / 110000) * (
        1 + 0.1 * min(1, nobjs / 1500)
    )
    if score < 500000:
        m = score / 500000 * 0.1
    elif score < 600000:
        m = (score - 500000) / 100000 * 0.2 + 0.1
    elif score < 700000:
        m = (score - 600000) / 100000 * 0.35 + 0.3
    elif score < 800000:
        m = (score - 700000) / 100000 * 0.2 + 0.65
    elif score < 900000:
        m = (score - 800000) / 100000 * 0.1 + 0.85
    else:
        m = (score - 900000) / 100000 * 0.05 + 0.95
    pp = pow(pow(k, 1.1) + pow(x * m, 1.1), 1 / 1.1) * 1.1

    return pp


def oppai_pp(ctx, acc, modded=True, taiko=False):
    """Get pp with oppai."""
    if not ctx.beatmap:
        return None

    path = scrape.download_beatmap(ctx)
    if path is None:
        return None

    cmd = [consts.oppai_bin, path, "%.3f%%" % acc, "-ojson"]

    if modded and ctx.mods != consts.nomod:
        cmd.append(combine_mods(ctx.mods))
    if taiko:
        cmd.append("-taiko")

    try:
        out = subprocess.check_output(cmd)
    except Exception as e:
        print("oppai command '%s' failed: %s" % (" ".join(cmd), e))
        os.remove(path)
        return None

    try:
        pp_j = json.loads(out)
    except Exception as e:
        print("Converting oppai output to JSON failed: %s\nOutput: %s" % (e, out))
        return None
    pp = pp_j.get("pp")

    # Certain broken maps can't be calculated and so they return -1.
    # See https://github.com/Francesco149/oppai-ng/issues/17.
    return None if pp == -1 else pp

import json
import math
import os
import subprocess

from . import consts, scrape
from .utils import combine_mods


def pp_val(ctx, acc, modded=True):
    """Get pp earned for a play with given acc."""
    return {
        consts.std: std_pp,
        consts.taiko: taiko_pp,
        consts.ctb: ctb_pp,
        consts.mania: mania_pp,
    }[ctx.mode](ctx, acc, modded=modded) if ctx.mode is not None else None


def std_pp(ctx, acc, modded=True):
    """Get pp for a standard map."""
    return oppai_pp(ctx, acc, modded=modded)


def taiko_pp(ctx, acc, modded=True):
    """Get pp for a Taiko map."""
    return oppai_pp(ctx, acc, modded=modded, taiko=True)


def ctb_pp(ctx, acc, modded=True):
    """Get pp for a CTB play."""
    if modded:
        return None
    max_combo = ctb_max_combo(ctx)
    if max_combo is None:
        return None

    sr = ctx.beatmap.difficultyrating
    ar = ctx.beatmap.diff_approach

    # Disclaimer: I did not write this.
    pp = pow(((5 * sr / 0.0049) - 4), 2) / 100000
    length_bonus = 0.95 + 0.4 * min(1, max_combo / 3000)
    if max_combo > 3000:
        length_bonus += math.log10(max_combo / 3000) * 0.5
    pp *= length_bonus
    # pp *= pow(0.97, nmiss)  # Irrelevant here, we assume FC.
    # pp *= pow(combo / max_combo, 0.8)  # Irrelevant here, we assume FC.
    if ar > 9:
        pp *= 1 + 0.1 * (ar - 9)

    return pp * pow(acc / 100, 5.5)


def mania_pp(ctx, acc, modded=True, score=None):
    """Get pp for a mania map. This is not guaranteed to be accurate."""
    if modded:
        return None  # TODO: Look into https://github.com/semyon422/omppc.
    nobjs = scrape.map_objects(ctx)
    if nobjs is None:
        return None
    nobjs = nobjs[0] + nobjs[1]

    # Score approximation is very rough.
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
    k = 2.5 * pow((150 / f) * pow(acc, 16), 1.8) * \
        min(1.15, pow(nobjs / 1500, 0.3))
    x = (pow(5 * max(1, sr / 0.0825) - 4, 3) / 110000) * \
        (1 + 0.1 * min(1, nobjs / 1500))
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

    return pow(pow(k, 1.1) + pow(x * m, 1.1), 1 / 1.1) * 1.1


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
        print(
            "Converting oppai output to JSON failed: %s\nOutput: %s" %
            (e, out)
        )
        return None
    pp = pp_j.get("pp")
    return None if pp == -1 else pp


def ctb_max_combo(ctx):
    """Find or approximate a CTB map's max combo."""
    if not ctx.beatmap:
        return None
    combo = scrape.max_combo(ctx)

    if combo is not None:
        return combo

    nobjs = scrape.map_objects(ctx)
    # https://gist.github.com/christopher-dG/216e4a43618a9a68a03e9db48e30e66b
    return (nobjs[0] + round(2.4*nobjs[1])) if nobjs is not None else None

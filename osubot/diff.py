import rosu_pp_py as rosu

from . import consts, scrape
from .utils import changes_diff, is_ignored


def diff_vals(ctx, modded=True):
    """Get the difficulty values of a map."""
    if not ctx.beatmap:
        return None
    if not modded:
        return diff_nomod(ctx)
    if modded and is_ignored(ctx.mods):
        return None
    return diff_modded(ctx)


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
    if is_ignored(ctx.mods):
        return None
    path = scrape.download_beatmap(ctx)
    if path is None:
        return None
    bm = rosu.Beatmap(path=path)
    diff = rosu.Difficulty(mods=ctx.mods)
    result = diff.calculate(bm)
    if ctx.mods & consts.mods2int["DT"]:  # This catches NC too.
        scalar = 1.5
    elif ctx.mods & consts.mods2int["HT"]:
        scalar = 0.75
    else:
        scalar = 1
    bpm = ctx.beatmap.bpm * scalar
    length = round(ctx.beatmap.total_length / scalar)
    if changes_diff(ctx.mods):
        stars = result.stars
    else:
        stars = ctx.beatmap.difficultyrating
    # https://redd.it/6phntt
    cs = ctx.beatmap.diff_size
    if ctx.mods & consts.mods2int["HR"]:
        cs *= 1.3
    elif ctx.mods & consts.mods2int["EZ"]:
        cs /= 2
    return {
        "cs": cs,
        "ar": result.ar,
        "od": result.od,
        "hp": result.hp,
        "sr": stars,
        "bpm": bpm,
        "length": length,
    }

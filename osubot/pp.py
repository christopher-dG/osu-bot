import rosu_pp_py as rosu

from . import consts, scrape


def pp_val(ctx, acc, modded=True):
    """Get pp earned for a play with given acc."""
    if ctx.mode is None:
        return None
    path = scrape.download_beatmap(ctx)
    if path is None:
        return None
    bm = rosu.Beatmap(path=path)
    bm.convert(consts.int2rosumode[ctx.mode])
    mods = ctx.mods if modded else consts.nomod
    perf = rosu.Performance(mods=mods, accuracy=acc)
    return perf.calculate(bm).pp

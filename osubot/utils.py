from . import consts


def map_str(beatmap):
    if not beatmap:
        return None
    return "%s - %s [%s]" % (beatmap.artist, beatmap.title, beatmap.version)


def combine_mods(mods):
    mods_a = []
    for k, v in consts.mods2int.items():
        if v & mods == v:
            mods_a.append(k)

    ordered_mods = list(filter(lambda m: m in mods_a, consts.mod_order))
    "NC" in ordered_mods and ordered_mods.remove("DT")
    "PF" in ordered_mods and ordered_mods.remove("SD")

    return "+%s" % "".join(ordered_mods) if ordered_mods else "NoMod"

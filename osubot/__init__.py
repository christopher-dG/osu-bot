import re

from . import consts
from . import parse_title


class Context:
    """A container for all relevant data."""
    def __init__(self, player, beatmap, mode, mods, acc):
        self.player = player  # osuapi.models.User, None if missing
        self.beatmap = beatmap  # osuapi.models.Beatmap, None if missing
        self.mode = mode  # Int (0-4, 0 if missing)
        self.mods = mods  # Int, 0 if missing
        self.acc = acc  # Float (0-1, None if missing)

    def __repr__(self):
        acc = self.acc * 100 if self.acc is not None else "None"
        s = "Context:\n"
        s += "  Player:   %s\n" % self.player
        s += "  Beatmap:  %s\n" % map_str(self.beatmap)
        s += "  Mode:     %s\n" % consts.mode2str[self.mode]
        s += "  Mods:     %s\n" % combine_mods(self.mods)
        s += "  Acc:      %.2f%%" % acc
        return s


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


def main(title):
    """Main driver function going from submission title to posting a reply."""
    print("Post title: %s" % title)

    if not re.match(consts.title_re, title):
        print("Not a score post")
        return False

    player = parse_title.getplayer(title)
    beatmap = parse_title.getmap(title, player=player)
    mode = parse_title.getmode(title, beatmap=beatmap)
    mods = parse_title.getmods(title)
    acc = parse_title.getacc(title)

    if mode != consts.std:
        player = consts.osu_api.get_user(
            player.user_id,
            mode=consts.mode2osuapi[mode],
        )

    ctx = Context(player, beatmap, mode, mods, acc)
    print(ctx)

    return True

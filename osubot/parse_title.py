import re

from . import consts
from .beatmap_search import search


def getplayer(title):
    """Get the player from the post title."""
    cap = re.findall(consts.player_re, title)
    if not cap:
        return None
    cap = cap[0].strip()

    name = cap  # TODO: Strip away annotations.

    player = consts.osu_api.get_user(name)
    return player[0] if player else None


def getmap(title, player=None):
    """Search for the beatmap."""
    cap = re.findall(consts.map_re, title)
    if not cap:
        print("Couldn't get betmap name match")
        return None

    return search(player, cap[0].strip())


def getmode(title, beatmap=None):
    """
    Search for the game mode.
    If title doesn't contain any relevant information, use beatmap's mode.
    If beatmap is None, then return None for unknown.
    """
    return consts.std


def getmods(title):
    """Search for mods in title."""
    return consts.mods2int[""]


def getacc(title):
    """Search for accuracy in title."""
    cap = re.findall(consts.acc_re, title)
    return float(cap[0]) / 100 if cap else None

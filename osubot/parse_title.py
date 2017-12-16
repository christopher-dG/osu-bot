from . import consts
from .beatmap_search import search


def getplayer(title):
    """Get the player from the post title."""
    match = consts.player_re.search(title)
    if not match:
        return None

    name = match.group(1).strip()  # TODO: Strip away annotations.

    player = consts.osu_api.get_user(name)
    return player[0] if player else None


def getmap(title, player=None):
    """Search for the beatmap."""
    match = consts.map_re.search(title)
    if not match:
        print("Couldn't get beatmap name match")
        return None

    return search(player, match.group(1).strip())


def getmode(title, beatmap=None):
    """
    Search for the game mode.
    If title doesn't contain any relevant information, use beatmap's mode.
    If beatmap is None, then return None for unknown.
    """
    return consts.std


def getmods(title):
    """Search for mods in title."""
    match = consts.tail_re.search(title)
    if not match:
        return consts.nomod
    tail = match.group(1)

    if "+" in tail and tail.index("+") < (len(tail) - 1):
        tokens = tail[(tail.index("+") + 1):].split()
        if tokens:
            return getmods_token(tokens[0])

    for token in tail.split():
        mods = getmods_token(token)
        if mods != consts.nomod:
            return mods

    return consts.nomod


def getmods_token(token):
    """Get mods from a single token."""
    token = consts.scorev2_re.sub("V2", token.upper().replace(",", ""))
    if len(token) % 2:
        return consts.nomod
    return sum(set(
        consts.mods2int.get(token[i:i+2], 0) for i in range(0, len(token), 2)
    ))


def getacc(title):
    """Search for accuracy in title."""
    match = consts.tail_re.search(title)
    if not match:
        return None
    match = consts.acc_re.search(match.group(1))
    return float(match.group(1)) / 100 if match else None

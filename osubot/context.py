from . import consts
from .beatmap_search import search, search_events
from .utils import combine_mods, map_str


class Context:
    """A container for all relevant data."""
    def __init__(self, player, beatmap, mode, mods, acc):
        self.player = player  # osuapi.models.User, None if missing
        self.beatmap = beatmap  # osuapi.models.Beatmap, None if missing
        self.mode = mode  # Int (0-4, 0 if missing)
        self.mods = mods  # Int, 0 if missing
        self.acc = acc  # Float (0-100, None if missing)

    def __repr__(self):
        acc = "%.2f%%" % (self.acc) if self.acc is not None else "None"
        s = "Context:\n"
        s += "> Player:   %s\n" % self.player
        s += "> Beatmap:  %s\n" % map_str(self.beatmap)
        s += "> Mode:     %s\n" % consts.mode2str[self.mode]
        s += "> Mods:     %s\n" % combine_mods(self.mods)
        s += "> Acc:      %s" % acc
        return s


def build_ctx(title):
    player = getplayer(title)
    beatmap = getmap(title, player=player)
    mode = getmode(title, player=player, beatmap=beatmap)
    mods = getmods(title)
    acc = getacc(title)

    if mode is not None and mode != consts.std:
        try:
            player = consts.osu_api.get_user(
                player.user_id,
                mode=consts.int2osuapimode[mode],
            )[0]
        except Exception as e:
            print("Couldn't get player with updated mode: %s" % e)

    return Context(player, beatmap, mode, mods, acc)


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


def getmode(title, player=None, beatmap=None):
    """
    Search for the game mode.
    If title doesn't contain any relevant information, try player's events.
    Otherwise, use beatmap's mode.
    If beatmap is None, then return None for unknown.
    """
    match = consts.player_re.match(title)
    if not match:
        return None
    playername = match.group(1)

    for match in consts.paren_re.findall(playername):
        if match in consts.mode_annots:
            return consts.mode_annots[match]
    for match in consts.bracket_re.findall(playername):
        if match in consts.mode_annots:
            return consts.mode_annots[match]

    if beatmap:
        if player:
            m = search_events(player, "", b_id=beatmap.beatmap_id, mode=True)
            if m is not None:
                return m
        return beatmap.mode.value

    return None


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
    return float(match.group(1)) if match else None

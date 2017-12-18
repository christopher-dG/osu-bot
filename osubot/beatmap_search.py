from . import consts
from .utils import api_wrap, compare, request


def search(player, beatmap):
    """Search for beatmap with player."""
    if player:
        result = search_events(player, beatmap)
        if result:
            return result
        result = search_recent(player, beatmap)
        if result:
            return result

    result = search_osusearch(beatmap)
    if result:
        return result

    print("Couldn't find map")
    return None


def search_events(player, beatmap, mode=False, b_id=None):
    """
    Search player's recent events for beatmap.
    If mode is False, returns the beatmap.
    Otherwise, returns the game mode of the event.
    """
    for event in player.events:
        match = consts.event_re.search(event.display_html)
        if not match:
            continue
        if (b_id is not None and event.beatmap_id == b_id) or \
           compare(match.group(1), beatmap):
            if mode:
                return consts.eventstr2mode.get(match.group(2), None)
            b_id = event.beatmap_id
            beatmaps = api_wrap(consts.osu_api.get_beatmaps, beatmap_id=b_id)
            if beatmaps:
                return beatmaps[0]

    return None


def search_recent(player, beatmap):
    """Search player's recent plays for beatmap."""
    recent = api_wrap(consts.osu_api.get_user_recent, player.user_id, limit=50)
    if not recent:
        return None

    ids = []
    for score in recent:
        if score.beatmap_id in ids:
            continue
        ids.append(score.beatmap_id)

        beatmaps = api_wrap(
            consts.osu_api.get_beatmaps,
            beatmap_id=score.beatmap_id,
        )
        if not beatmaps:
            continue
        bmap = beatmaps[0]

        map_str = "%s - %s [%s]" % (bmap.artist, bmap.title, bmap.version)
        if compare(map_str, beatmap):
            return bmap

    return None


def search_osusearch(beatmap):
    """Search osusearch.com for beatmap."""
    match = consts.map_pieces_re.search(beatmap)
    if not match:
        print("Beatmap string '%s' was not well formed" % beatmap)
        return None
    artist, title, diff = match.groups()

    params = {
        "key": consts.osusearch_key,
        "artist": artist.strip(),
        "title": title.strip(),
        "diff_name": diff.strip(),
    }

    # TODO: Maybe canonicalize the URL.

    resp = request(consts.osusearch_url, text=False, params=params)
    if not resp:
        return None

    try:
        d = resp.json()
    except Exception as e:
        print("Couldn't load JSON from osusearch: %s" % e)
        return None

    beatmaps = d.get("beatmaps", [])
    if not beatmaps:
        return None

    fav_map = max(beatmaps, key=lambda m: m.get("favorites", 0))
    beatmaps = api_wrap(
        consts.osu_api.get_beatmaps,
        beatmap_id=fav_map["beatmap_id"],
    )
    return beatmaps[0] if beatmaps else None

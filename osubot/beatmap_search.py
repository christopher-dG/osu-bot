import requests

from . import consts
from .utils import api_wrap, safe_call


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
    slug = beatmap.upper().replace(" ", "")

    for event in player.events:
        match = consts.event_re.search(event.display_html)
        if not match:
            continue
        if (
                (b_id is not None and event.beatmap_id == b_id) or
                match.group(1).upper().replace(" ", "") == slug
        ):
            if mode:
                return consts.eventstr2mode[match.group(2)]
            b_id = event.beatmap_id
            beatmaps = api_wrap(consts.osu_api.get_beatmaps, beatmap_id=b_id)
            if beatmaps:
                return beatmaps[0]

    return None


def search_recent(player, beatmap):
    """Search player's recent plays for beatmap."""
    recent = api_wrap(consts.osu_api.get_user_recent, player.user_id, limit=50)

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
        if map_str.upper() == beatmap.upper():
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

    resp = safe_call(
        requests.get,
        consts.osusearch_url,
        alt=None,
        params=params,
    )
    if resp is None:
        return None
    if resp.status_code != 200:
        print("osusearch returned %d" % resp.status_code)
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

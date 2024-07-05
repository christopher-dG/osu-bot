import datetime

from . import consts
from .utils import compare, map_str, request, safe_call


def search(player, beatmap, logs=[]):
    """Search for beatmap with player."""
    if player:
        result = search_events(player, beatmap)
        if result:
            logs.append("Beatmap: Found in events")
            return result
        result = search_best(player, beatmap)
        if result:
            logs.append("Beatmap: Found in best")
            return result
        result = search_recent(player, beatmap)
        if result:
            logs.append("Beatmap: Found in recent")
            return result

    result = search_osusearch(beatmap)
    if result:
        logs.append("Beatmap: Found with osusearch")
        return result

    logs.append("Beatmap '%s': Not found" % beatmap)
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
        if (b_id is not None and event.beatmap_id == b_id) or compare(
            match.group(1), beatmap
        ):
            if mode:
                return consts.eventstr2mode.get(match.group(2), None)
            b_id = event.beatmap_id
            beatmaps = safe_call(consts.osu_api.get_beatmaps, beatmap_id=b_id)
            if beatmaps:
                return beatmaps[0]

    return None


def search_best(player, beatmap):
    """Search player's best plays for beatmap."""
    best = safe_call(consts.osu_api.get_user_best, player.user_id, limit=100)
    if not best:
        return None

    today = datetime.datetime.today()
    threshold = datetime.timedelta(weeks=1)
    for score in filter(lambda s: today - s.date < threshold, best):
        beatmaps = safe_call(consts.osu_api.get_beatmaps, beatmap_id=score.beatmap_id,)
        if not beatmaps:
            continue
        bmap = beatmaps[0]

        if compare(map_str(bmap), beatmap):
            return bmap

    return None


def search_recent(player, beatmap):
    """Search player's recent plays for beatmap."""
    recent = safe_call(consts.osu_api.get_user_recent, player.user_id, limit=50)  # noqa
    if not recent:
        return None

    ids = []
    for score in recent:
        if score.beatmap_id in ids:
            continue
        ids.append(score.beatmap_id)

        beatmaps = safe_call(consts.osu_api.get_beatmaps, beatmap_id=score.beatmap_id,)
        if not beatmaps:
            continue
        bmap = beatmaps[0]

        if compare(map_str(bmap), beatmap):
            return bmap

    return None


# NOTE: I am pretty sure osusearch.com is down for good..
def search_osusearch(beatmap):
    """Search osusearch.com for beatmap."""
    match = consts.map_pieces_re.search(beatmap)
    if not match:
        return None
    artist, title, diff = match.groups()

    params = {
        "key": consts.osusearch_key,
        "artist": artist.strip(),
        "title": title.strip(),
        "diff_name": diff.strip(),
    }

    resp = request(consts.osusearch_url, text=False, params=params)
    if not resp:
        return None

    try:
        d = resp.json()
    except Exception as e:
        return None

    beatmaps = d.get("beatmaps", [])
    if not beatmaps:
        return None

    matching_maps = list(
        filter(
            lambda m: compare(
                beatmap,
                "%s - %s [%s]" % (m["artist"], m["title"], m["difficulty_name"]),
            ),
            beatmaps,
        )
    )
    if not matching_maps:
        return None

    fav_map = max(matching_maps, key=lambda m: m.get("favorites", 0))
    beatmaps = safe_call(consts.osu_api.get_beatmaps, beatmap_id=fav_map["beatmap_id"],)
    return beatmaps[0] if beatmaps else None

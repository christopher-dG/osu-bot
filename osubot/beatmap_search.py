import requests

from . import consts


def search(player, beatmap):
    """Search for beatmap with player."""
    if player:
        result = search_events(player, beatmap)
        if result:
            print("Found map %d in recent events" % result.beatmap_id)
            return result
        result = search_recent(player, beatmap)
        if result:
            print("Found map %d in recent plays" % result.beatmap_id)
            return result

    result = search_osusearch(beatmap)
    if result:
        print("Found map %d with osusearch" % result.beatmap_id)
        return result

    print("Couldn't find map")
    return None


def search_events(player, beatmap):
    """Search player's recent events for beatmap."""
    slug = beatmap.upper().replace(" ", "")

    for event in player.events:
        match = consts.event_re.search(event.display_html)
        if not match:
            continue
        if match.group(1).upper().replace(" ", "") == slug:
            b_id = event.beatmap_id
            try:
                return consts.osu_api.get_beatmaps(beatmap_id=b_id)[0]
            except Exception as e:
                print("Getting beatmap %d failed: %s" % (b_id, e))

    return None


def search_recent(player, beatmap):
    """Search player's recent plays for beatmap."""
    recent = consts.osu_api.get_user_recent(player.user_id, limit=50)

    ids = []
    for score in recent:
        if score.beatmap_id in ids:
            continue
        ids.append(score.beatmap_id)

        try:
            bmap = consts.osu_api.get_beatmaps(beatmap_id=score.beatmap_id)[0]
        except Exception as e:
            continue

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

    url = "%s?key=%s" % (consts.osusearch_url, consts.osusearch_key)
    url += "&artist=%s" % artist.strip()
    url += "&title=%s" % title.strip()
    url += "&diff_name=%s" % diff.strip()

    # TODO: Maybe canonicalize the URL.

    resp = requests.get(url)
    if resp.status_code != 200:
        print("osusearch returned %d" % resp.statusCode)
        return None
    try:
        beatmaps = resp.json()["beatmaps"]
    except Exception as e:
        print("Couldn't load beatmaps from osusearch: %s" % e)
        return None

    if not beatmaps:
        return None

    os_map = max(beatmaps, key=lambda m: m["favorites"])
    try:
        return consts.osu_api.get_beatmaps(beatmap_id=os_map["beatmap_id"])[0]
    except Exception as e:
        print("Converting osusearch map to osuapi map failed: %s" % e)
        return None

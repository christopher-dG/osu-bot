from typing import Optional

from bs4 import BeautifulSoup
from osuapi.model import Beatmap, OsuMod, Score as OsuScore, User
from pylev import levenshtein


from .globals import logger

_osusearch_key = os.getenv("OSUSEARCH_API_KEY")
_osusearch_api = "https://osusearch.com/api"
_re_acc = re.compile(r"(\d{1,3}(?:[\.,]\d+)?)%")
_re_beatmap = re.compile(r"\|(.+)-(.+?)\[(.+)\]")
_re_tail = re.compile(r".+\|.+-.+\[.+\](.*)")


class Score:
    """TODO"""
    pass


def from_title(title: str, user: Optional[User] = None) -> Optional[Score]:
    logger.info(f"Processing title: {title}")
    m = _re_beatmap.search(title)
    if not m:
        logger.error(f"Title is not a score post match")
        return None
    beatmap = _beatmap(m.string, *m.groups(), user)
    if not beatmap:
        logger.error("Beatmap was not found")
        return None
    tail = _re_tail.search(title)[0]
    mods = _parse_mods(tail)
    logger.debug("Found mods: {mods.shortname}")


def _beatmap(
        target: str, artist: str, title: str, diff: str, user: Optional[User]
) -> Optional[Beatmap]:
    logger.info(f"Looking for beatmap: {target}")
    if user:
        logger.info(f"Searching with user {user.username}")
        target = target.strip()
        beatmap = __beatmap_from_events(user, target)
        if beatmap:
            logger.info(f"Found beatmap {beatmap.beatmap_id} in events")
            return beatmap
        else:
            logger.warning("Did not find beatmap in events")
        beatmap = __beatmap_from_recent(user, target)
        if beatmap:
            logger.info(f"Found beatmap {beatmap.beatmap_id} in recent")
            return beatmap
        else:
            logger.warning("Did not find beatmap in recent")
        beatmap = __beatmap_from_top(user, target)
        if beatmap:
            logger.info(f"Found beatmap {beatmap.beatmap_id} in top")
            return beatmap
        else:
            logger.warning("Did not find beatmap in top")
    else:
        logger.warning("No user available for beatmap search")
    beatmap = __beatmap_from_osusearch(target, artist, title, diff)
    if beatmap:
        logger.info(f"Found beatmap {beatmap.beatmap_id} with osusearch")
        return beatmap
    else:
        logger.warning("Did not find beatmap with osusearch")
        return None



def __beatmap_from_events(user: User, target: str) -> Optional[Beatmap]:
    for event in user.events:
        soup = BeautifulSoup(event.display_html)
        for a in soup.find_all("a"):
            if __compare(a.text, target):
                logger.debug(f"Found matching event: {a.text}")
                return osu_api.get_beatmap(event.beatmap_id)
    return None


def __make_search(
        get_scores: Callable[[User], List[OsuScore]]
) -> Callable[[User, str], Optional[Beatmap]]:
    def search(user: User, target: str) -> Optional[Beatamp]:
        for score in get_scores(user):
            beatmap = osu_api.get_beatmap(score.beatmap_id)
            if __compare(__format(beatmap), target):
                return beatmap
        return None


__beatmap_from_recent = __make_search(osu_api.get_user_recent)
__beatmap_from_top = __make_search(osu_api.get_user_top)

def __beatmap_from_osusearch(
        target: str, artist: str, title: str, diff: str
) -> Optional[Beatmap]:
    resp = http.get(f"{_osusearch_api}/search", params={
        "key": _osusearch_key,
        "artist": artist.strip(),
        "title": title.strip(),
        "diff_name": diff.strip(),
    })
    if not resp:

        return None



def __format(beatmap: Beatmap) -> str:
    return f"{beatmap.artist} - {beatmap.title} [{beatmap.version}]"


def __compare(a: str, b: str) -> bool:
    a = a.lower().replace(" ", "").replace("&quot;", "\"").replace("&amp;", "&")
    b = b.lower().replace(" ", "").replace("&quot;", "\"").replace("&amp;", "&")
    return levenshtein(a, b) < 3




def _accuracy(text: str) -> Optional[float]:
    m = _re_acc.search(title)
    if m:
        logger.debug(f"Found accuracy: {m[1]}%")
        accuracy = float(m[1]) / 100
    else:
        logger.warning("Didn't find accuracy")
        accuracy = None


def _parse_mods(text: str) -> OsuMod:
    text = text.replace(", ", "")
    if "+" in text:
        # Happy path: +HDHR, etc.
        text = text[text.index("+") + 1:].split()[0]

def __parse_mods(word: str) -> Optional[Osumod]:
    word = word.lstrip("+").replace(",", "")
    if len(s) % 2:
        return None
    tokens =  [word[i:i+2] for i in range(0, len(word), 2)]
    if
    for mod in OsuMod.__flags_members:
        pass

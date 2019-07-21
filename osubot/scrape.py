import json

from typing import Any, Dict, List, Optional, Union

from bs4 import BeautifulSoup
from osuapi.model import Beatmap, User
from requests_cache import CachedSession

from .globals import http_session, logger
from .urls import osu_web


def _user_data(user: User) -> Optional[Dict[str, Any]]:
    """Get user data from the osu! web site."""
    url = f"{osu_web}/u/{user.user_id}"
    resp = http_session.get(url)
    if resp.status_code != 200:
        logger.warning(f"Request for {url} returned {resp.status_code}")
        return None
    soup = BeautifulSoup(resp.text, "html.parser")
    script = soup.find("script", id="json-user")
    if script is None:
        logger.warning("No element with id=json-user was found at {url}")
        return None
    try:
        return json.loads(script.text)
    except ValueError:
        logger.warning(
            "Content of element with id=json-user from {url} is not valid JSON"
        )
        return None


def previous_usernames(user: User) -> List[str]:
    """Get a user's previous usernames."""
    data = _user_data(user)
    if not data:
        return []
    if "previous_usernames" not in data:
        logger.warning(f"Key 'previous_usernames' not found in data for user {user}")
        return []
    return data["previous_usernames"]


def playstyle(user: Union[int, str]) -> List[str]:
    """Get a user's playstyle."""
    data = _user_data(user)
    if not data:
        return []
    if "playstyle" not in data:
        logger.warning(f"Key 'playstyles' not found in data for user {user}")
        return []
    return data["playstyle"]

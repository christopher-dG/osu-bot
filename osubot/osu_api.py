import os

from typing import List, Optional, Union

from osuapi import Beatmap, OsuApi, ReqConnector, Score, User
from requests_cache import CachedSession

_api = OsuApi(
    os.getenv("OSU_API_KEY"), connector=ReqConnector(CachedSession(backend="memory"))
)


def get_user(user: Union[int, str], **kwargs) -> Optional[User]:
    """Get a user."""
    if isinstance(user, int):
        kwargs["type"] = "id"
    elif isinstance(user, str):
        kwargs["type"] = "username"
    kwargs.setdefault("event_days", 31)
    users = _api.get_user(user, **kwargs)
    return users[0] if users else None


def get_beatmap(beatmap: int, **kwargs) -> Optional[Beatmap]:
    """Get a beatmap."""
    beatmaps = _api.get_beatmaps(beatmap_id=beatmap, **kwargs)
    return beatmaps[0] if beatmaps else None


def get_scores(beatmap: Union[Beatmap, int], **kwargs) -> List[Score]:
    """Get a beatmap's top scores."""
    if isinstance(beatmap, Beatmap):
        kwargs.setdefault("mode", beatmap.mode)
        beatmap = beatmap.beatmap_id
    kwargs.setdefault("limit", 100)
    return _api.get_scores(beatmap, **kwargs)


def get_user_best(user: Union[int, str, User], **kwargs) -> List[Score]:
    """Get a user's best scores."""
    if isinstance(user, User):
        user = user.user_id
    kwargs.setdefault("limit", 100)
    return _api.get_user_best(user, **kwargs)


def get_user_recent(user: Union[int, str, User], **kwargs) -> List[Score]:
    """Get a user's recent scores."""
    if isinstance(user, User):
        user = user.user_id
    kwargs.setdefault("limit", 100)
    return _api.get_user_recent(user, **kwargs)


def get_user_beatmaps(user: Union[int, str, User], **kwargs) -> List[Beatmap]:
    return _api.get_beatmaps(username=user, **kwargs)

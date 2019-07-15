from dataclasses import dataclass
from typing import Dict, List, Optional

from osuapi.model import Beatmap, BeatmapStatus, OsuMode, Score, User

from . import osu_api


@dataclass
class Context:
    beatmap: Beatmap
    player: User
    mode: OsuMode
    mapper: Mapper
    guest_mapper: Optional[Mapper]
    score: Score


class Mapper:
    user: User
    beatmaps: Dict[BeatmapStatus, List[Beatmap]]

    def __init__(self, user: User):
        self.user = user
        beatmaps = osu_api.get_user_beatmaps(user)
        # todo: status -> list.

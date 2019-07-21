import logging
import os

from requests_cache import CachedSession

http_session = CachedSession(backend="memory")
logger = logging.getLogger("osu!bot")
osu_web = "https://osu.ppy.sh"
tillerino_api = "https://api.tillerino.org"

logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))
logging.basicConfig(
    format="%(levelname)s %(asctime)s %(module)s.%(funcName)s: %(message)s",
    datefmt="%a %H:%M:%S",
)

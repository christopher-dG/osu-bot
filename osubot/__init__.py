import logging
import os

from . import handlers

logger = logging.getLogger("osu!bot")
logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))
logging.basicConfig(
    format="%(levelname)s %(asctime)s %(module)s.%(funcName)s: %(message)s",
    datefmt="%a %H:%M:%S",
)

# TODO: Delete me
from . import osu_api, stats

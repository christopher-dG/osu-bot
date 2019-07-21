import hashlib
import json
import subprocess

from functools import lru_cache
from pathlib import Path
from tempfile import gettempdir
from typing import Dict, Optional
from urllib.parse import urlparse
from zipfile import ZipFile, ZIP_DEFLATED

import catch_the_pp

from osuapi.model import Beatmap, OsuMod, OsuMode, Score

from . import aws
from .globals import http_session, logger, osu_web, tillerino_api

_oppai_bin = "oppai"
_osu_file_dir = Path(gettempdir()) / "osu"
_osu_file_dir.mkdir(exist_ok=True)


class Stats:
    """A container for beatmap stats."""

    ar: float
    bpm: float
    combo: Optional[int]
    cs: float
    hp: float
    od: float
    length: float
    pp: Optional[float]
    sr: float

    def __init__(self, beatmap: Beatmap, mods: OsuMod, **kwargs):
        self.ar = kwargs.get("ar", beatmap.diff_approach)
        self.combo = kwargs.get("combo", beatmap.max_combo)
        self.cs = kwargs.get("cs", beatmap.diff_size)
        self.hp = kwargs.get("hp", beatmap.diff_drain)
        self.od = kwargs.get("od", beatmap.diff_overall)
        self.sr = kwargs.get("sr", beatmap.difficultyrating)
        self.pp = kwargs.get("pp")
        self.bpm = beatmap.bpm
        self.length = beatmap.total_length
        if OsuMod.DoubleTime in mods:
            self.bpm *= 1.5
            self.length *= 2 / 3
        elif OsuMod.HalfTime in mods:
            self.bpm *= 0.75
            self.length /= 0.75


def compute(
    beatmap: Beatmap,
    mode: OsuMode,
    mods: OsuMod = OsuMod.NoMod,
    accuracy: float = 1.0,
    score: Optional[Score] = None,
) -> Optional[Stats]:
    """Compute beatmap stats."""
    if mode in [OsuMode.osu, OsuMode.taiko]:
        return _oppai(beatmap, mode, mods, accuracy)
    elif mode == OsuMode.ctb:
        return _ctb(beatmap, mods, accuracy)
    elif mode == OsuMode.mania:
        return _mania(beatmap, mods, accuracy, score)
    else:
        logger.error("Unknown mode {mode}")
        return None


def _download_osu(beatmap: Beatmap) -> Optional[Path]:
    """Download a beatmap's .osu file."""
    osu_dest = _osu_file_dir / f"{beatmap.file_md5}.osu"
    if osu_dest.is_file():
        logger.info(f"Beatmap {beatmap.beatmap_id} file {osu_dest} already exists")
        return osu_dest
    path = aws.s3_get_object(f"osu/{beatmap.file_md5}.zip")
    if path is not None:
        with ZipFile(path) as f:
            f.extractall(_osu_file_dir)
        if osu_dest.is_file():
            return osu_dest
        else:
            logger.warning(f"Expected .zip file to contain {osu_dest.name}")
    path = _request_osu(
        f"{osu_web}/osu/{beatmap.beatmap_id}", beatmap.file_md5, osu_dest
    )
    if path is not None:
        return path
    path = _request_osu(
        f"{tillerino_api}/beatmaps/byHash/{beatmap.file_md5}",
        beatmap.file_md5,
        osu_dest,
    )
    if path is not None:
        return path
    logger.warning(f"Beatmap {beatmap.beatmap_id} ({beatmap.file_md5}) not downloaded")
    return None


def _upload_osu(path: Path) -> None:
    """Upload a beatmap's .osu file to the S3 store."""
    if path.suffix != ".osu":
        logger.error(f"Only .osu files should be uploaded, not {path.suffix}")
        return
    zip_path = _osu_file_dir / f"{path.stem}.zip"
    with ZipFile(zip_path, "w") as f:
        f.write(path, compress_type=ZIP_DEFLATED)
    aws.s3_put_object(f"osu/{zip_path.name}", zip_path)


def _request_osu(url: str, md5: str, dest: Path) -> Optional[Path]:
    """Request a .osu file from somewhere."""
    resp = http_session.get(url)
    code = resp.status_code
    content_type = resp.headers["Content-Type"]
    if code == 200 and "text/plain" in content_type:
        if hashlib.md5(resp.text.encode("utf-8")).hexdigest() == md5:
            with open(dest, "w") as f:
                f.write(resp.text)
            _upload_osu(dest)
            return dest
        else:
            logger.warning(f"Mismatched  hashes (expected {md5})")
    else:
        loc = urlparse(url).netloc
        logger.warning(f"Bad code ({code}) or type ({content_type}) from {loc}")
    return None


@lru_cache()
def _oppai(
    beatmap: Beatmap, mode: OsuMode, mods: OsuMod, accuracy: float
) -> Optional[Stats]:
    """Compute an osu!standard or osu!taiko beatmap's stats."""
    if mode not in [OsuMode.osu, OsuMode.taiko]:
        logger.error(f"Can't use oppai for mode {mode}")
        return None
    path = _download_osu(beatmap)
    if path is None:
        return None
    args = [_oppai_bin, str(path), "-ojson", f"{accuracy * 100}%", f"-m{mode.value}"]
    if mods != OsuMod.NoMod:
        args.append(f"+{mods.shortname}")
    # TODO: Is -taiko actually necessary when -m1 is present?
    if mode == OsuMode.taiko:
        args.append("-taiko")
    logger.info("$ " + " ".join(args))
    proc = subprocess.run(args, capture_output=True)
    if proc.stderr:
        logger.debug(proc.stderr.decode("utf-8"))
    if proc.stdout:
        logger.debug(proc.stdout.decode("utf-8"))
    if proc.returncode != 0:
        logger.warning(f"Exit code: {proc.returncode}")
        return None
    try:
        data = json.loads(proc.stdout)
    except ValueError:
        logger.warning("oppai produced invalid JSON output")
        return None
    # https://github.com/Francesco149/oppai-ng/issues/17
    if data["pp"] == -1:
        data["pp"] = None
    return Stats(
        beatmap,
        mods,
        ar=data["ar"],
        cs=data["cs"],
        hp=data["hp"],
        od=data["od"],
        pp=data["pp"],
        sr=data["stars"],
    )


@lru_cache()
def _ctb(beatmap: Beatmap, mods: OsuMod, accuracy: float) -> Optional[Stats]:
    """Compute an osu!catch beatmap's stats."""
    path = _download_osu(beatmap)
    if path is None:
        return None
    ctb_map = catch_the_pp.osu_parser.beatmap.Beatmap(path)
    ctb_diff = catch_the_pp.osu.ctb.difficulty.Difficulty(ctb_map, mods.value)
    pp = catch_the_pp.ppCalc.calculate_pp(ctb_diff, accuracy, ctb_map.max_combo, 0)
    return Stats(
        beatmap,
        mods,
        ar=ctb_map.difficulty["ApproachRate"],
        combo=ctb_map.max_combo,
        cs=ctb_map.difficulty["CircleSize"],
        hp=ctb_map.difficulty["HPDrainRate"],
        od=ctb_map.difficulty["OverallDifficulty"],
        pp=pp,
        sr=ctb_diff.star_rating,
    )


@lru_cache()
def _mania(
    beatmap: Beatmap, mods: OsuMod, accuracy: float, score: Optional[Score]
) -> Optional[Stats]:
    """Compute an osu!mania beatmap's stats."""
    # TODO: pp and mod calculation, done properly (http://maniapp.uy.to).
    if mods != OsuMod.NoMod:
        logger.warning("Modded stats cannot be computed for osu!mania")
        return None
    logger.info("osu!mania pp calculation is not implemented")
    return Stats(beatmap, mods)

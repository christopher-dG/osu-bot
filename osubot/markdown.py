import markdown_strings as md

from . import consts, scrape
from .utils import accuracy, combine_mods, map_str


def build_comment(ctx):
    """Build a full comment from ctx."""
    return "\n\n".join([
        map_header(ctx),
        map_table(ctx),
        player_table(ctx),
        "***",
        footer(ctx),
    ])


def map_header(ctx):
    """Return a line or two with basic map information."""
    b = ctx.beatmap
    map_link = md.link(map_str(b), "%s/b/%d" % (consts.osu_url, b.beatmap_id))
    dl_link = md.link(
        "(%s)" % consts.dl,
        "%s/d/%d" % (consts.osu_url, b.beatmap_id),
    )
    mapper_id = scrape.mapper_id(ctx)
    mapper = mapper_id if mapper_id is not None else b.creator
    mapper_url = "%s/u/%s" % (consts.osu_url, mapper)
    mapper_link = md.link(b.creator, mapper_url)
    buf = "%s %s by %s" % (map_link, dl_link, mapper_link)

    if consts.status2str[b.approved.value] == "Unranked":
        buf += " || Unranked"
        if b.approed_date is not None:
            buf += " (%s)" % (b.approved_date)
        return md.header(buf, 4)

    header = md.header(buf, 4)

    rank_one = map_rank_one(ctx)
    buf = ("%s || " % rank_one) if rank_one else ""

    max_combo = scrape.max_combo(ctx)
    if max_combo is not None:
        buf += "%dx max combo || " % max_combo
    buf += "%s" % consts.status2str[b.approved.value]
    if b.approved_date:
        buf += " (%s)" % b.approved_date.date()
    subheader = md.bold(buf)

    return "%s\n%s" % (header, subheader)


def map_table(ctx):
    return ""


def player_table(ctx):
    return ""


def footer(ctx):
    return ""


def map_rank_one(ctx):
    """Fetch and format the top play for a beatmap."""
    mode = ctx.mode if ctx.mode is not None else consts.std
    apimode = consts.int2osuapimode[mode]
    scores = consts.osu_api.get_scores(
        ctx.beatmap.beatmap_id,
        mode=apimode,
        limit=1,
    )
    if not scores:
        return None
    score = scores[0]

    player = consts.osu_api.get_user(score.username, mode=apimode)
    p_id = player[0].user_id if player else score.username
    player_link = md.link(score.username, "%s/u/%s" % (consts.osu_url, p_id))

    buf = "#1: %s (" % player_link
    if score.enabled_mods.value != consts.nomod:
        buf += "%s - " % combine_mods(score.enabled_mods)
    buf += "%.2f%%" % accuracy(score, mode)
    if score.pp is not None:
        buf += " - %.2fpp" % score.pp
    buf += ")"
    return buf

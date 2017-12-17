import markdown_strings as md
import random

from . import consts, diff, pp, scrape
from .utils import (
    accuracy,
    api_wrap,
    combine_mods,
    map_str,
    round_to_str,
    str_to_timestamp,
)


def build_comment(ctx):
    """Build a full comment from ctx."""
    comment = "\n\n".join(filter(
        bool,
        [
            map_header(ctx),
            map_table(ctx),
            player_table(ctx),
            "***",
            footer(ctx),
        ],
    ))
    return None if comment.startswith("***") else comment


def map_header(ctx):
    """Return a line or two with basic map information."""
    if not ctx.beatmap:
        print("No beatmap; skipping map header")
        return None
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
    if not ctx.beatmap:
        print("No beatmap; skipping map table")
        return None

    nomod = diff.diff_vals(ctx, modded=False)
    if nomod is None:
        print("Couldn't get nomod diff values")
        return None
    if ctx.mods == consts.nomod:
        print("Skipping modded diff values")
        modded = None
    else:
        modded = diff.diff_vals(ctx, modded=True)

    r = round_to_str
    if modded:
        cols = [
            ["", "NoMod", combine_mods(ctx.mods)],
            ["CS", r(nomod["cs"], 1), r(modded["cs"], 1)],
            ["AR", r(nomod["ar"], 1), r(modded["ar"], 1)],
            ["OD", r(nomod["od"], 1), r(modded["od"], 1)],
            ["HP", r(nomod["hp"], 1), r(modded["hp"], 1)],
            [
                "SR",
                r(nomod["sr"], 2, force=True),
                r(modded["sr"], 2, force=True),
            ],
            ["BPM", round(nomod["bpm"]), round(modded["bpm"])],
            [
                "Length",
                str_to_timestamp(nomod["length"]),
                str_to_timestamp(modded["length"]),
            ],
        ]
    else:
        cols = [
            ["CS", r(nomod["cs"], 1)],
            ["AR", r(nomod["ar"], 1)],
            ["OD", r(nomod["od"], 1)],
            ["HP", r(nomod["hp"], 1)],
            ["SR", r(nomod["sr"], 2, force=True)],
            ["BPM", round(nomod["bpm"])],
            ["Length", str_to_timestamp(nomod["length"])],
        ]

    pp_vals = {}
    if not modded:
        print("Skipping modded pp values")
    for acc in filter(bool, set([95, 98, 99, 100, ctx.acc])):
        nomod_pp = pp.pp_val(ctx, acc, modded=False)
        if nomod_pp is None:
            continue

        if modded:
            modded_pp = pp.pp_val(ctx, acc, modded=True)
            if modded_pp is not None:
                pp_vals[acc] = nomod_pp, modded_pp
        else:
            pp_vals[acc] = nomod_pp, None

    accs_joined = (" %s " % consts.bar).join(
        "%s%%" % r(a, 2, force=True)
        if int(a) != a else str(a) for a in sorted(pp_vals.keys()),
    )
    nomod_joined = (" %s " % consts.bar).join(
        r(pp_vals[acc][0], 0) for acc in sorted(pp_vals.keys()),
    )

    cols.append(["pp (%s)" % accs_joined, nomod_joined])
    if modded:
        modded_joined = (" % s " % consts.bar).join(
            r(pp_vals[acc][1], 0) for acc in sorted(pp_vals.keys()),
        )
        cols[-1].append(modded_joined)

    return md.table([[str(x) for x in col] for col in cols])


def player_table(ctx):
    if not ctx.player:
        print("No player; skipping player table")
        return None

    return None


def footer(ctx):
    buf = "^(%s - )" % random.choice(consts.memes)
    buf += md.link("^Source", consts.repo_url)
    buf += "^( | )"
    buf += md.link("^Developer", consts.me)
    # TODO: Add usage instructions link when commands are ready.
    buf += "^( | )"
    buf += md.link("^([Unnoticed]: Unranked leaderboards)", consts.unnoticed)

    if ctx.beatmap and ctx.mode in [consts.ctb, consts.mania]:
        buf += "^( | CTB/Mania pp is experimental)"

    return buf


def map_rank_one(ctx):
    """Fetch and format the top play for a beatmap."""
    if not ctx.beatmap:
        print("No beatmap; skipping rank one")
        return None

    mode = ctx.mode if ctx.mode is not None else consts.std
    apimode = consts.int2osuapimode[mode]
    scores = api_wrap(
        consts.osu_api.get_scores,
        ctx.beatmap.beatmap_id,
        mode=apimode,
        limit=1,
    )
    if not scores:
        print("No scores found for beatmap")
        return None
    score = scores[0]

    players = api_wrap(consts.osu_api.get_user, score.username, mode=apimode)
    p_id = players[0].user_id if players else score.username
    player_link = md.link(score.username, "%s/u/%s" % (consts.osu_url, p_id))

    buf = "#1: %s (" % player_link
    if score.enabled_mods.value != consts.nomod:
        buf += "%s - " % combine_mods(score.enabled_mods.value)
    buf += "%.2f%%" % accuracy(score, mode)
    if score.pp is not None:
        buf += " - %dpp" % round(score.pp)
    buf += ")"
    return buf

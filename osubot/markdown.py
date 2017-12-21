import copy
import markdown_strings as md
import random

from . import consts, diff, pp, scrape
from .utils import (
    accuracy,
    api,
    combine_mods,
    escape,
    map_str,
    nonbreaking,
    round_to_str,
    sep,
    s_to_ts,
)


def build_comment(ctx):
    """Build a full comment from ctx."""
    if not ctx.player and not ctx.beatmap:
        print("No player or beatmap; aborting")
        return None

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

    map_url = "%s/b/%d" % (consts.osu_url, b.beatmap_id)
    if ctx.mode is not None:
        map_url += "?m=%d" % ctx.mode
    map_link = md.link(escape(map_str(b)), map_url)
    dl_link = md.link(
        "(%s)" % consts.dl,
        "%s/d/%d" % (consts.osu_url, b.beatmap_id),
    )
    mapper_id = scrape.mapper_id(ctx)
    mapper = b.creator if mapper_id is None else mapper_id
    mapper_url = "%s/u/%s" % (consts.osu_url, mapper)

    rename = mapper_renamed(ctx, mapper_id=mapper_id)
    hover = "Renamed to '%s'" % rename if rename is not None else ""

    counts = mapper_counts(ctx, mapper=mapper)
    if counts:
        hover += ": %s" % counts if hover else counts

    if hover:
        mapper_url += " \"%s\"" % hover

    mapper_link = md.link(escape(b.creator), mapper_url)
    buf = "%s %s by %s" % (map_link, dl_link, mapper_link)

    if ctx.mode is not None:
        buf += " || %s" % consts.mode2str[ctx.mode]

    if consts.int2status[b.approved.value] == "Unranked":
        buf += " || Unranked"
        if b.approved_date is not None:
            buf += " (%s)" % (b.approved_date)
        return md.header(buf, 4)

    header = md.header(buf, 4)

    rank_one = map_rank_one(ctx)
    buf = ("%s || " % rank_one) if rank_one else ""

    max_combo = scrape.max_combo(ctx)
    if max_combo is not None:
        buf += "%sx max combo || " % sep(max_combo)
    buf += "%s" % consts.int2status[b.approved.value]
    if b.approved_date:
        buf += " (%s)" % b.approved_date.date()
    if b.playcount > 0:
        buf += " || %s plays" % sep(b.playcount)

    subheader = md.bold(buf)

    return "%s\n%s" % (header, subheader)


def map_table(ctx):
    """Build a table with map difficulty and pp values."""
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
                s_to_ts(nomod["length"]),
                s_to_ts(modded["length"]),
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
            ["Length", s_to_ts(nomod["length"])],
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
        "%s%%" % (r(a, 2, force=True) if int(a) != a else str(a))
        for a in sorted(pp_vals.keys()),
    )
    nomod_joined = (" %s " % consts.bar).join(
        sep(round(pp_vals[acc][0])) for acc in sorted(pp_vals.keys()),
    )

    if pp_vals:
        cols.append(["pp (%s)" % accs_joined, nomod_joined])
        if modded:
            modded_joined = (" % s " % consts.bar).join(
                sep(round(pp_vals[acc][1])) for acc in sorted(pp_vals.keys()),
            )
            cols[-1].append(modded_joined)

    return centre_table(md.table([[str(x) for x in col] for col in cols]))


def player_table(ctx):
    """Build a table with player information."""
    if not ctx.player:
        print("No player; skipping player table")
        return None
    p = ctx.player
    if p.pp_rank is None:
        print("Player is inactive in mode: %s" % consts.mode2str[ctx.mode])
        return None

    rank = "#%s (#%s %s)" % (sep(p.pp_rank), sep(p.pp_country_rank), p.country)
    player_link = md.link(
        nonbreaking(escape(p.username)),
        "%s/u/%d" % (consts.osu_url, p.user_id),
    )
    cols = [
        ["Player", player_link],
        ["Rank", nonbreaking(rank)],
        ["pp", sep(round(p.pp_raw))],
        ["Acc", "%s%%" % round_to_str(p.accuracy, 2, force=True)],
        ["Playcount", sep(p.playcount)],
    ]

    mode = ctx.mode if ctx.mode is not None else consts.std
    scores = api(
        consts.osu_api.get_user_best,
        ctx.player.user_id,
        mode=consts.int2osuapimode[mode],
        limit=1,
    )
    if scores:
        score = scores[0]
        beatmaps = api(
            consts.osu_api.get_beatmaps,
            beatmap_id=score.beatmap_id,
            mode=consts.int2osuapimode[mode],
            include_converted=True,
        )
        if beatmaps:
            bmap = beatmaps[0]
            map_url = "%s/b/%d" % (consts.osu_url, bmap.beatmap_id)
            if ctx.mode is not None:
                map_url += "?m=%d" % ctx.mode

            ctx_clone = copy.deepcopy(ctx)
            ctx_clone.beatmap = bmap
            ctx_clone.mods = score.enabled_mods.value
            ctx_clone.mode = mode
            hover = map_hover(ctx_clone)

            map_link = "%s \"%s\"" % (map_url, hover) if hover else map_url

            buf = md.link(nonbreaking(escape(map_str(bmap))), map_link)

            mods = combine_mods(score.enabled_mods.value)
            if mods:
                buf += " %s %s" % (mods, consts.bar)

            buf += " %s%%" % round_to_str(accuracy(score, mode), 2, force=True)

            if score.pp:
                buf += " %s %spp" % (consts.bar, sep(round(score.pp)))

            cols.append(["Top Play", buf])

    return centre_table(md.table([[str(x) for x in col] for col in cols]))


def footer(ctx):
    """Return a footer with some general information."""
    buf = "^(%s – )" % random.choice(consts.memes)
    buf += md.link("^Source", consts.repo_url)
    buf += "^( | )"
    buf += md.link("^Developer", consts.me)
    # TODO: Add usage instructions link when commands are ready.
    buf += "^( | )"
    buf += md.link("^([Unnoticed]: Unranked leaderboards)", consts.unnoticed)

    exp_pp = bool(ctx.beatmap) and ctx.beatmap.mode.value != ctx.mode
    exp_pp |= ctx.mode in [consts.ctb, consts.mania]
    if exp_pp:
        if ctx.mode == consts.taiko:
            mode = "Autoconverted Taiko"
        else:
            mode = consts.mode2str[ctx.mode]
        buf += "^( | %s pp is experimental)" % mode

    return buf


def map_rank_one(ctx):
    """Fetch and format the top play for a beatmap."""
    if not ctx.beatmap:
        print("No beatmap; skipping rank one")
        return None

    mode = ctx.mode if ctx.mode is not None else consts.std
    apimode = consts.int2osuapimode[mode]
    scores = api(
        consts.osu_api.get_scores,
        ctx.beatmap.beatmap_id,
        mode=apimode,
        limit=1,
    )
    if not scores:
        print("No scores found for beatmap")
        return None
    score = scores[0]

    players = api(consts.osu_api.get_user, score.username, mode=apimode)
    p_id = players[0].user_id if players else score.username
    player_link = md.link(
        escape(score.username),
        "%s/u/%s" % (consts.osu_url, p_id),
    )

    buf = "#1: %s (" % player_link
    if score.enabled_mods.value != consts.nomod:
        buf += "%s - " % combine_mods(score.enabled_mods.value)
    buf += "%.2f%%" % accuracy(score, mode)
    if score.pp is not None:
        buf += " - %spp" % sep(round(score.pp))
    buf += ")"
    return buf


def mapper_counts(ctx, mapper=None):
    """Get the number of maps per status for a beatmap's mapper."""
    if not ctx.beatmap:
        return None

    if not mapper:
        mapper_id = scrape.mapper_id(ctx)
        mapper = ctx.beatmap.creator if mapper_id is None else mapper_id

    maps = api(
        consts.osu_api.get_beatmaps,
        username=mapper,
        mode=consts.int2osuapimode.get(ctx.mode),
    )
    if not maps:
        return None

    groups = {k: 0 for k in consts.status2str}
    ids = []
    for b in [(m.beatmapset_id, m.approved.value) for m in maps]:
        if b[0] in ids:
            continue
        ids.append(b[0])
        if consts.int2status.get(b[1]) in groups:
            groups[consts.int2status[b[1]]] += 1

    return "%s ranked, %s qualified, %s loved, %s unranked" % \
        tuple(sep(groups[k]) for k in ["Ranked", "Qualified", "Loved", "Unranked"])  # noqa


def mapper_renamed(ctx, mapper_id=None):
    """Check if the mapper of ctx's beatmap has renamed."""
    if not mapper_id:
        mapper_id = scrape.mapper_id(ctx)
        if mapper_id is None:
            return None

    mapper_updated = api(consts.osu_api.get_user, mapper_id)
    if mapper_updated and mapper_updated[0].username != ctx.beatmap.creator:
        return mapper_updated[0].username

    return None


def map_hover(ctx):
    """Generate link hover text for a beatmap."""
    if not ctx.beatmap:
        return None

    d = diff.diff_vals(ctx, modded=ctx.mods != consts.nomod)
    if not d:
        return None

    r = round_to_str
    return "SR%s - CS%s - AR%s - OD%s - HP%s - %dBPM - %s" % (
        r(d["sr"], 2, force=True), r(d["cs"], 1), r(d["ar"], 1), r(d["od"], 1),
        r(d["hp"], 1), d["bpm"], s_to_ts(d["length"]),
    )


def centre_table(t):
    """Centre cells in a Markdown table."""
    lines = t.split("\n")
    return t.replace(lines[1], "|".join([":-:"] * (lines[0].count("|") - 1)))

import copy
import markdown_strings as md
import random

from . import consts, diff, pp, scrape
from .utils import (
    accuracy,
    combine_mods,
    map_str,
    nonbreaking,
    round_to_str,
    safe_call,
    sep,
    s_to_ts,
)


def build_comment(ctx):
    """Build a full comment from ctx."""
    if not ctx.player and not ctx.beatmap:
        return None

    comment = "\n\n".join(
        filter(
            bool,
            [map_header(ctx), map_table(ctx), player_table(ctx), "***", footer(ctx),],
        )
    )

    return None if comment.startswith("***") else comment


def map_header(ctx):
    """Return a line or two with basic map information."""
    if not ctx.beatmap:
        return None
    b = ctx.beatmap

    map_url = "%s/b/%d" % (consts.osu_url, b.beatmap_id)
    if ctx.mode is not None:
        map_url += "?m=%d" % ctx.mode
    map_link = md.link(map_str(b), map_url)
    dl_link = md.link(
        "(%s)" % consts.dl,
        '%s/d/%d "Download this beatmap"' % (consts.osu_url, b.beatmapset_id),  # noqa
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
        mapper_url += ' "%s"' % hover

    mapper_link = md.link(b.creator, mapper_url)
    map_s = "%s %s by %s" % (map_link, dl_link, mapper_link)

    if ctx.guest_mapper:
        guest_url = "%s/u/%d" % (consts.osu_url, ctx.guest_mapper.user_id)
        counts = mapper_counts(ctx, mapper=ctx.guest_mapper.user_id)
        if counts:
            guest_url += ' "%s"' % counts
        guest_link = md.link(ctx.guest_mapper.username, guest_url)
        map_s += " (GD by %s)" % guest_link

    tokens = [map_s]

    unranked = consts.int2status[b.approved.value] == "Unranked"

    if not unranked and ctx.mode is not None:
        tokens.append(consts.mode2str[ctx.mode])

    header = md.header(" || ".join(tokens), 4)
    subheader = (unranked_subheader if unranked else approved_subheader)(ctx)

    return "%s\n%s" % (header, subheader)


def approved_subheader(ctx):
    """Build a subheader for a ranked/qualified/loved beatmap."""
    tokens = []

    rank_one = map_rank_one(ctx)
    if rank_one is not None:
        tokens.append(rank_one)

    max_combo = scrape.max_combo(ctx)
    if max_combo is not None:
        tokens.append("%sx max combo" % sep(max_combo))

    status = consts.int2status[ctx.beatmap.approved.value]
    if ctx.beatmap.approved_date is not None and status != "Qualified":
        status += " (%d)" % ctx.beatmap.approved_date.year
    tokens.append(status)

    if ctx.beatmap.playcount:
        tokens.append("%s plays" % sep(ctx.beatmap.playcount))

    return md.bold(" || ".join(tokens))


def unranked_subheader(ctx):
    """Build a subheader for an unranked beatmap."""
    tokens = []
    if ctx.mode is not None:
        tokens.append(consts.mode2str[ctx.mode])

    max_combo = scrape.max_combo(ctx)
    if max_combo is not None:
        tokens.append("%sx max combo" % sep(max_combo))

    tokens.append("Unranked")

    return md.bold(" || ".join(tokens))


def map_table(ctx):
    """Build a table with map difficulty and pp values."""
    if not ctx.beatmap:
        return None

    nomod = diff.diff_vals(ctx, modded=False)
    if nomod is None:
        return None
    if ctx.mods == consts.nomod:
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
            ["SR", r(nomod["sr"], 2, force=True), r(modded["sr"], 2, force=True),],
            ["BPM", round(nomod["bpm"]), round(modded["bpm"])],
            ["Length", s_to_ts(nomod["length"]), s_to_ts(modded["length"]),],
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
        (
            "%s%%" % (r(a, 2, force=True) if int(a) != a else str(a))
            for a in sorted(pp_vals.keys())
        )
    )
    nomod_joined = (" %s " % consts.bar).join(
        (sep(round(pp_vals[acc][0])) for acc in sorted(pp_vals.keys()))
    )

    if pp_vals:
        cols.append(["pp (%s)" % accs_joined, nomod_joined])
        if modded:
            modded_joined = (" % s " % consts.bar).join(
                (sep(round(pp_vals[acc][1])) for acc in sorted(pp_vals.keys()))
            )
            cols[-1].append(modded_joined)

    return centre_table(md.table([[str(x) for x in col] for col in cols]))


def player_table(ctx):
    """Build a table with player information."""
    if not ctx.player:
        return None
    p = ctx.player
    if not p.pp_raw:  # Player is inactive so most stats are null.
        return None

    rank = "#%s (#%s %s)" % (sep(p.pp_rank), sep(p.pp_country_rank), p.country)

    player_url = "%s/u/%d" % (consts.osu_url, p.user_id)
    old_username = scrape.player_old_username(ctx)
    if old_username and old_username.lower() != p.username.lower():
        player_url += " \"Previously known as '%s'\"" % old_username
    player_link = md.link(nonbreaking(p.username), player_url)

    cols = [
        ["Player", player_link],
        ["Rank", nonbreaking(rank)],
        ["pp", sep(round(p.pp_raw))],
        ["Accuracy", "%s%%" % round_to_str(p.accuracy, 2, force=True)],
        ["Playcount", sep(p.playcount)],
    ]

    # There's no point getting playstyle for non-standard players.
    playstyle = scrape.playstyle(ctx) if ctx.mode == consts.std else None
    if playstyle is not None:
        cols.insert(4, ["Playstyle", playstyle])  # Place after acc.

    mode = ctx.mode if ctx.mode is not None else consts.std
    scores = safe_call(
        consts.osu_api.get_user_best,
        ctx.player.user_id,
        mode=consts.int2osuapimode[mode],
        limit=1,
    )
    if scores:
        score = scores[0]
        beatmaps = safe_call(
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
            hover = map_hover(ctx_clone, oldmap=ctx.beatmap, oldmods=ctx.mods)

            if hover:
                map_url += ' "%s"' % hover

            map_link = md.link(nonbreaking(map_str(bmap)), map_url)

            mods = combine_mods(score.enabled_mods.value)
            buf = "%s %s " % (mods, consts.bar) if mods else ""

            buf += "%s%%" % round_to_str(accuracy(score, mode), 2, force=True)

            if score.pp:
                buf += " %s %spp" % (consts.bar, sep(round(score.pp)))

            cols.append(["Top Play", "%s %s" % (map_link, nonbreaking(buf))])

    return centre_table(md.table([[str(x) for x in col] for col in cols]))


def footer(ctx):
    """Return a footer with some general information and hidden logs."""
    tokens = [
        md.link("^Source", consts.repo_url),
        md.link("^Developer", consts.me),
    ]

    # TODO: Add usage instructions link when commands are ready.

    # if random.random() < consts.promo_rate:
    #     tokens.append(md.link(
    #         "^([Unnoticed]: Unranked leaderboards)",
    #         consts.unnoticed,
    #     ))

    exp_pp = bool(ctx.beatmap) and ctx.beatmap.mode.value != ctx.mode
    exp_pp |= ctx.mode in [consts.ctb, consts.mania]
    if exp_pp:
        if ctx.mode == consts.taiko:
            mode = "Autoconverted "
        else:
            mode = ""
        mode += consts.mode2str[ctx.mode]
        tokens.append("^(%s pp is experimental)" % mode)

    text = "^(%s – )%s" % (random.choice(consts.memes), "^( | )".join(tokens))
    logs = md.link(  # Invisible link with hover text.
        consts.spc, 'http://x "%s"' % "\n".join(s.replace('"', "'") for s in ctx.logs),
    )
    return "%s %s" % (text, logs)


def map_rank_one(ctx):
    """Fetch and format the top play for a beatmap."""
    if not ctx.beatmap:
        return None

    mode = ctx.mode if ctx.mode is not None else consts.std
    apimode = consts.int2osuapimode[mode]
    scores = safe_call(
        consts.osu_api.get_scores, ctx.beatmap.beatmap_id, mode=apimode, limit=2,
    )
    if not scores:
        return None
    score = scores[0]

    use_two = bool(ctx.player) and score.user_id == ctx.player.user_id
    use_two &= score.enabled_mods.value == ctx.mods

    if use_two and len(scores) > 1:
        score = scores[1]

    players = safe_call(consts.osu_api.get_user, score.user_id, mode=apimode)
    if players:
        ctx_clone = copy.deepcopy(ctx)
        ctx_clone.player = players[0]
        hover = player_hover(ctx_clone, oldplayer=ctx.player)
    else:
        hover = None
    player_url = "%s/u/%s" % (consts.osu_url, score.user_id)
    if hover:
        player_url += ' "%s"' % hover
    player_link = md.link(score.username, player_url)

    player = "#%d: %s" % (2 if use_two else 1, player_link)
    tokens = []

    if score.enabled_mods.value != consts.nomod:
        tokens.append(combine_mods(score.enabled_mods.value))
    tokens.append("%.2f%%" % accuracy(score, mode))
    if score.pp is not None:
        tokens.append("%spp" % sep(round(score.pp)))

    return "%s (%s)" % (player, " - ".join(tokens))


def mapper_counts(ctx, mapper=None):
    """Get the number of maps per status for a beatmap's mapper."""
    if not ctx.beatmap:
        return None

    if not mapper:
        mapper_id = scrape.mapper_id(ctx)
        mapper = ctx.beatmap.creator if mapper_id is None else mapper_id

    maps = safe_call(consts.osu_api.get_beatmaps, username=mapper)
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

    return "%s ranked, %s qualified, %s loved, %s unranked" % tuple(
        sep(groups[k]) for k in ["Ranked", "Qualified", "Loved", "Unranked"]
    )  # noqa


def mapper_renamed(ctx, mapper_id=None):
    """Check if the mapper of ctx's beatmap has renamed."""
    if not mapper_id:
        mapper_id = scrape.mapper_id(ctx)
        if mapper_id is None:
            return None

    mapper_updated = safe_call(consts.osu_api.get_user, mapper_id)
    if mapper_updated and mapper_updated[0].username != ctx.beatmap.creator:
        return mapper_updated[0].username

    return None


def map_hover(ctx, oldmap=None, oldmods=None):
    """Generate link hover text for a beatmap."""
    if not ctx.beatmap:
        return None
    if oldmap and ctx.beatmap.beatmap_id == oldmap.beatmap_id and ctx.mods == oldmods:
        return None

    d = diff.diff_vals(ctx, modded=ctx.mods != consts.nomod)
    if not d:
        return None

    return " - ".join(
        [
            "SR%s" % round_to_str(d["sr"], 2, force=True),
            "CS%s" % round_to_str(d["cs"], 1),
            "AR%s" % round_to_str(d["ar"], 1),
            "OD%s" % round_to_str(d["od"], 1),
            "HP%s" % round_to_str(d["hp"], 1),
            "%dBPM" % d["bpm"],
            s_to_ts(d["length"]),
        ]
    )


def player_hover(ctx, oldplayer=None):
    """Generate link hover text for a player."""
    if not ctx.player or (oldplayer and ctx.player.user_id == oldplayer.user_id):
        return None
    p = ctx.player
    if not p.pp_raw:  # Player is inactive so most stats are null.
        return None

    return " - ".join(
        [
            "%spp" % sep(round(p.pp_raw)),
            "rank #%s (#%s %s)"
            % (sep(p.pp_rank), sep(p.pp_country_rank), p.country),  # noqa
            "%s%% accuracy" % round_to_str(p.accuracy, 2, force=True),
            "%s playcount" % sep(p.playcount),
        ]
    )


def centre_table(t):
    """Centre cells in a Markdown table."""
    lines = t.split("\n")
    return t.replace(lines[1], "|".join([":-:"] * (lines[0].count("|") - 1)))

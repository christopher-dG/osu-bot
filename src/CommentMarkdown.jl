"""
Tools for building comments.
"""
module CommentMarkdown

using Formatting

using OsuBot.Oppai
using OsuBot.Osu
using OsuBot.OsuTypes
using OsuBot.Utils

export build_comment, footer

const osu = "https://osu.ppy.sh"
const bar = "&#124;"
const download = "&#x2b07;"
const space = "&nbsp;"
const hyphen = "&#x2011;"
const source_url = "https://github.com/christopher-dG/OsuBot.jl"
const me = "https://reddit.com/u/PM_ME_DOG_PICS_PLS"
const readme = "$source_url/blob/master/README.md#summoning-the-bot"
const ignore_mods = [:NF, :PF, :AP, :RL, :AT]
const memes = [
    "pls enjoy gaem",
    "play more",
    "Ye XD",
    "imperial dead bicycle lol",
    "nice pass ecks dee",
    "kirito is legit",
    "can just shut up",
    "thank mr monstrata",
    "fc cry thunder and say that me again",
    "tbh i don't think fils has the aim for this",
    "omg kappadar big fan",
    "reese get the camera",
    "cookiezi hdhr when",
    "TATOE",
    "hello there",
    "rrtyui :(",
]

footer() = "***\n\n^($(rand(memes)) - )[^Source]($source_url)^( | )[^Developer]($me)^( | )[^Usage]($readme)"

"""
    map_table!(buf::IO, beatmap::Beatmap, accuracy::Real, mods::Int, mode::Mode) -> Void

Produce a table containing difficulty and pp values, and write it to `buf`.
"""
function map_table!(buf::IO, beatmap::Beatmap, accuracy::Real, mods::Int, mode::Mode)
    modded = mods != mod_map[:NOMOD]
    log("Getting map table for $(map_name(beatmap)) with$(modded ? "" : "out") mods")

    header, nomod_row = if modded && in(mode, [OsuTypes.STD, OsuTypes.TAIKO])
        [""], ["NoMod"]
    else
        String[], String[]
    end
    rows = [header, nomod_row]
    push!(header, "CS", "AR", "OD", "HP", "SR", "BPM", "Length")
    map_diff = get_diff(beatmap)
    push!(
        nomod_row,
        strfmt(map_diff[:CS]),
        strfmt(map_diff[:AR]),
        strfmt(map_diff[:OD]),
        strfmt(map_diff[:HP]),
        strfmt(map_diff[:SR]; precision=2),
        strfmt(map_diff[:BPM]; precision=0),
        map_diff[:LEN],
    )

    if in(mode, [OsuTypes.STD, OsuTypes.TAIKO])
        pp_vals = Dict{Real, AbstractFloat}()
        for acc in sort(Real[accuracy, 95, 98, 99, 100])
            pp = get_pp(beatmap, acc; taiko=mode == OsuTypes.TAIKO)
            if pp != nothing
                pp_vals[acc] = pp
            end
        end
        accs = sort(collect(keys(pp_vals)))
        if !isempty(pp_vals)
            push!(
                header,
                "pp ($(join(map(v -> "$v%", strfmt.(accs; precision=2)), " $bar ")))",
            )
            push!(
                nomod_row,
                join(map(acc -> strfmt(pp_vals[acc]; precision=0), accs), " $bar "),
            )
        else
            modded = false
        end
    end

    mod_list = mods_from_int(mods)
    if modded && in(mode, [OsuTypes.STD, OsuTypes.TAIKO]) && !isempty(setdiff(mod_list, ignore_mods))
        modded_row = ["+$(join(mod_list))"]
        map_diff = get_diff(beatmap, mods)
        push!(
            modded_row,
            strfmt(map_diff[:CS]),
            strfmt(map_diff[:AR]),
            strfmt(map_diff[:OD]),
            strfmt(map_diff[:HP]),
            strfmt(map_diff[:SR]; precision=2),
            strfmt(map_diff[:BPM]; precision=0),
            map_diff[:LEN],
        )

        pp_vals = filter(
            v -> v != nothing,
            map(acc -> get_pp(beatmap, acc, mods; taiko=mode == OsuTypes.TAIKO), accs),
        )
        push!(modded_row, join(strfmt.(pp_vals; precision=0), " $bar "))
        push!(rows, modded_row)
    end

    table = Markdown.Table(rows, repeat([:c]; outer=[length(header)]))
    Markdown.plain(buf, table)
    return nothing
end

function map_table!(buf::IO, beatmap::OtherBeatmap, acc::Real, mods::Int, mode::Mode)
    header, row = ["CS", "AR", "OD", "HP", "SR", "BPM", "Length"], String[]
    rows = [header, row]
    map_diff = get_diff(beatmap)
    push!(
        row,
        strfmt(map_diff[:CS]),
        strfmt(map_diff[:AR]),
        strfmt(map_diff[:OD]),
        strfmt(map_diff[:HP]),
        strfmt(map_diff[:SR]; precision=2),
        strfmt(map_diff[:BPM]; precision=0),
        map_diff[:LEN],
    )
    table = Markdown.Table(rows, repeat([:c]; outer=[length(header)]))
    Markdown.plain(buf, table)
    return nothing
end

"""
    build_comment(
        player::Nullable{User},
        beatmap::Nullable{<:Beatmap},
        mods::Int,
        acc::Nullable{<:Real},
        mode::Nullable{Mode},
    ) -> String

Build a comment from a player's play on a beatmap with given mods and accuracy.
When `acc` has no value we couldn't find the accuracy in the title, so we try to find a
play by `player` and use its accuracy. When `mode` has no value we don't yet know the game
mode, so we'll use the default beatmap mode, ignoring autoconverts.
"""
function build_comment(
    player::Nullable{User},
    beatmap::Nullable{<:Beatmap},
    mods::Int,
    acc::Nullable{<:Real},
    mode::Nullable{Mode},
)
    isnull(player) && isnull(beatmap) && error("Both player and beatmap are null")

    player_s = isnull(player) ? "null" : get(player).name
    map_s = isnull(beatmap) ? "null" : map_name(get(beatmap))
    acc_s = isnull(acc) ? "null" : "$(get(acc))%"
    mode_s = isnull(mode) ? "null" : get(mode)
    log("player=$player_s, beatmap=$map_s, mods=$mods, acc=$acc_s, mode=$mode_s")

    buf = IOBuffer()
    if !isnull(beatmap)
        map = get(beatmap)
        mode = isnull(mode) ? map.mode : get(mode)
        map_basics!(buf, map, mode)
        write(buf, "\n\n")
        # Either use the supplied accuracy value from the title, or go find one.
        # If things fail, set it to 100 so that no extra pp value is generated.
        acc = if isnull(acc)
            if isnull(player)
                log("Title didn't contain acc and player is null")
                100
            else
                log("Title didn't contain acc; looking for a play by $(get(player).name)")
                plays = beatmap_scores(map.id, get(player).id; mode=mode)
                if !isnull(plays)
                    plays = get(plays)
                    try first(plays).accuracy catch e log(e); 100 end
                else
                    log("Couldn't find a play")
                    100
                end
            end
        else
            get(acc)
        end
        map_table!(buf, map, acc, mods, mode)
        write(buf, "\n")
    else
        mode = get(mode, OsuTypes.STD)
    end

    if !isnull(player)
        player_table!(buf, get(player), mode)
        write(buf, "\n")
    end

    write(buf, footer())

    comment = String(take!(buf))

    # If for some reason neither the map or player information was generated, don't reply.
    if length(split(comment, "\n")) <= 1
        error("Only a footer was generated")
    else
        return comment
    end
end

"""
    map_basics!(buf::IO, map::Beatmap, mode::Mode; minimal::Bool=false) -> Void

Produce basic map information (name, mapper, playcount, etc.) and write it to `buf`.
If `minimal` is set, only get the map name and mapper name.
"""
function map_basics!(buf::IO, map::Beatmap, mode::Mode; minimal::Bool=false)
    mapper = get(map.mapper_id, map.mapper)
    tmp = "[$(map_name(map))]($osu/b/$(map.id)) [($download)]($osu/d/$(map.set_id)) "
    tmp *= "by [$(map.mapper)]($osu/u/$mapper)"
    if minimal
        Markdown.plain(buf, Markdown.Header(tmp, 5))
        return nothing
    end
    if map.status == "Unranked"
        # Unranked maps always come from osusearch, and they never have max combo set.
        tmp *= " || $(map.status)"
        if !isnull(map.approved_date)
            tmp *= " ($(get(map.approved_date)))"
        end
        Markdown.plain(buf, Markdown.Header(tmp, 5))
        return nothing
    end
    Markdown.plain(buf, Markdown.Header(tmp, 5))
    tmp = ""
    plays = beatmap_scores(map.id; mode=mode)
    if !isnull(plays)
        top = first(get(plays))
        # Output from `beatmap_scores` always has both `username` and `user_id` fields,
        # so we shouldn't need to handle `NullException`s.
        tmp = "#1: [$(get(top.username))]($osu/u/$(get(top.user_id))) ("
        if top.mods != mod_map[:NOMOD]
            tmp *= "+$(join(mods_from_int(top.mods))) - "
        end
        # `beatmap_scores` also always comes with `pp` set.
        tmp *= "$(strfmt(top.accuracy; precision=2))% - "
        tmp *= "$(strfmt(get(top.pp); precision=0))pp) || "
    end
    if isa(map, StdBeatmap) && map.combo != -1
        # Non-standard maps don't have max combo set, nor do maps from osusearch.
        tmp *= "$(strfmt(map.combo; precision=0))x max combo || "
    end
    tmp *= "$(map.status)"
    tmp *= isnull(map.approved_date) ? " || " : " ($(get(map.approved_date))) || "
    tmp *= "$(strfmt(map.plays; precision=0)) plays"
    Markdown.plaininline(buf, Markdown.Bold(tmp))
    # Markdown.Header always ends with a newline, so add one here too for consistency.
    write(buf, "\n")
    return nothing
end

"""
    player_table!(buf::IO, player::User, mode::Mode) -> Void

Produce a table containing player information and write it to `buf`.
"""
function player_table!(buf::IO, player::User, mode::Mode)
    # Now that we know what game mode we're dealing with, we can make sure that we get
    # stats for the right mode.
    if mode != OsuTypes.STD
        mode_player = user(player.id; mode=mode)
        if !isnull(mode)
            player = get(mode_player)
        end
    end
    header = ["Player", "Rank", "pp", "Acc", "Playcount"]
    # Usernames are short enough (15 characters max) to go on one line in their table cell.
    username = replace(player.name, " ", space)
    row = [
        "[$username]($osu/u/$(player.id))",
        "#$(strfmt(player.rank))",
        strfmt(player.pp),
        "$(strfmt(player.accuracy; precision=2))%",
        strfmt(player.playcount),
    ]
    rows = [header, row]
    plays = player_best(player.id; mode=mode, lim=1)
    if !isnull(plays)
        play = first(get(plays))
        map = beatmap(play.map_id)
        if !isnull(map)
            map = get(map)
            str = "[$(map_name(map))]($osu/b/$(map.id)) "
            mods = mods_from_int(play.mods)
            str *= isempty(mods) ? "$bar " : "+$(join(mods)) $bar "
            str *= "$(strfmt(play.accuracy; precision=2))% $bar $(strfmt(get(play.pp)))pp"
            push!(header, "Top Play")
            push!(row, str)
        end
    end
    table = Markdown.Table(rows, repeat([:c]; outer=[length(header)]))
    Markdown.plain(buf, table)
    return nothing
end

"""
    leaderboard!(buf::IO, map_id::Int; mods::Int=mod_map[:FREEMOD], n::Int=5) -> Void

Produce a table containing the top `n` plays for a map and write it to `buf`.
"""
function leaderboard!(buf::IO, map::Beatmap; mods::Int=mod_map[:FREEMOD], n::Int=5)
    scores = beatmap_scores(map.id; mods=mods, lim=n)
    isnull(scores) && error("Scores could not be retrieved")
    scores = get(scores)
    combo = try "Combo (/$(map.combo)x)" catch "Combo" end
    header, rows = ["", "Player", "Mods", "Acc", "pp", combo, "Date"], Vector{String}[]
    for (i, score) in enumerate(scores)
        mods = mods_from_int(score.mods)
        misses = score.misses == 0 ? "" : " ($(score.misses)x miss)"
        push!(
            rows,
            [
                string(i),
                "[$(get(score.username))]($osu/u/$(get(score.user_id)))",
                isempty(mods) ? "None" : "+$(join(mods))",
                "$(strfmt(score.accuracy; precision=2))%",
                strfmt(get(score.pp); precision=0),
                "$(score.combo)x$misses",
                replace("$(Date(score.date))", "-", hyphen),
            ],
        )
    end
    table = Markdown.Table([header, rows...], repeat([:c]; outer=[length(header)]))
    Markdown.plain(buf, table)
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

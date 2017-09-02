"""
Tools for building comments.
"""
module CommentMarkdown

using Formatting

using OsuBot.Oppai
using OsuBot.Osu
using OsuBot.OsuTypes
using OsuBot.Utils

export build_comment

const BAR = "&#124;"
const source_url = "https://github.com/christopher-dG/OsuBot.jl"
const me = "PM_ME_DOG_PICS_PLS"

function map_table!(buf::IO, beatmap::Beatmap, accuracy::Real, mods::Int)
    modded = mods != mod_map[:NOMOD]
    header, nomod_row = modded ? ([""], ["NoMod"]) : ([], [])
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
    pp_vals = Dict{Real, AbstractFloat}()
    for acc in sort(Real[accuracy, 95, 98, 99, 100])
        pp = get_pp(beatmap, acc)
        if pp != nothing
            pp_vals[acc] = pp
        end
    end
    accs = sort(collect(keys(pp_vals)))
    push!(header, "pp ($(join(map(v -> "$v%", strfmt.(accs; precision=2)), " $BAR ")))")
    push!(nomod_row, join(map(acc -> strfmt(pp_vals[acc]; precision=0), accs), " $BAR "))

    if modded
        modded_row = ["+$(join(mods_from_int(mods)))"]
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
        pp_vals = filter(v -> v != nothing, map(acc -> get_pp(beatmap, acc, mods), accs))
        push!(modded_row, join(strfmt.(pp_vals; precision=0), " $BAR "))
        push!(rows, modded_row)
    end

    table = Markdown.Table(rows, repeat([:c]; outer=[length(header)]))
    Markdown.plain(buf, table)
end

function map_table!(buf::IO, beatmap::OtherBeatmap, acc::Real, mods::Int)
    header, row = ["CS", "AR", "OD", "HP", "SR", "BPM", "Length"], []
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
end

"""
    build_comment(player::Player, beatmap::Beatmap) -> String

Build a comment from `player` and `beatmap`.
"""
function build_comment(player::Player, beatmap::Nullable{Beatmap})
    buf = IOBuffer()
    if !isnull(beatmap)
        map = get(beatmap)
        plays = beatmap_scores(map.id, player.id; mode=map.mode)
        if !isnull(plays)
            play = first(get(plays))
            acc = play.accuracy
            mods = play.mods
            map_basics!(buf, map)
            write(buf, "\n\n")
            map_table!(buf, map, acc, mods)
            write(buf, "\n")
        end
    end
    player_markdown!(buf, player, isnull(beatmap) ? STD : get(beatmap).mode)
    write(buf, "\n***\n\n^(I'm a bot. )[^Source]($source_url)^( | )[^Developer](/u/$me)")

    return String(take!(buf))
end

function map_basics!(buf::IO, map::Beatmap)
    const osu = "https://osu.ppy.sh"
    tmp = "[$(map_name(map))]($osu/b/$(map.id)) [(↓)]($osu/d/$(map.set_id)) "
    tmp *= "by [$(map.mapper)]($osu/u/$(map.mapper))"
    Markdown.plain(buf, Markdown.Header(tmp, 3))
    tmp = ""
    plays = beatmap_scores(map.id; mode=map.mode)
    if !isnull(plays)
        top = first(get(plays))
        # Output from `beatmap_scores` always has both `username` and `user_id` fields,
        # so we shouldn't need to handle `NullException`s.
        tmp = "#1: [$(get(top.username))]($osu/u/$(get(top.user_id))) ("
        if top.mods != mod_map[:NOMOD]
            tmp *= "+$(join(mods_from_int(top.mods))) - "
        end
        # `beatmap_scores` also always comes with `pp` set.
        tmp *= "$(strfmt(top.accuracy;precision=2))% - "
        tmp *= "$(strfmt(get(top.pp); precision=0))pp) || "
    end
    if isa(map, StdBeatmap)
        tmp *= "$(strfmt(map.combo; precision=0))x max combo || "
    end
    tmp *= "$(map.status) ($(map.approved_date)) || "
    tmp *= "$(strfmt(map.plays; precision=0)) plays"
    Markdown.plaininline(buf, Markdown.Bold(tmp))
end

function player_markdown!(buf::IO, player::Player, mode::Mode)
    const osu = "https://osu.ppy.sh"
    header = ["Player", "Rank", "pp", "Acc", "Playcount"]
    row = [
        "[$(player.name)]($osu/u/$(player.id))",
        "#$(strfmt(player.rank))",
        strfmt(player.pp),
        strfmt(player.accuracy; precision=2),
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
            str *= isempty(mods) ? "| " : "+$(join(mods)) | "
            str *= "$(strfmt(play.accuracy; precision=2))% | $(strfmt(get(play.pp)))pp"
            push!(header, "Top Play")
            push!(row, str)
        end
    end
    table = Markdown.Table(rows, repeat([:c]; outer=[length(header)]))
    Markdown.plain(buf, table)
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

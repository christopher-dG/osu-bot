"""
Tools for building comments, parsing mods, etc.
"""
module Utils

using Formatting

using OsuBot.Osu
using OsuBot.OsuTypes

export map_name, mods_from_int, mods_from_string, search, build_comment

"""
    map_name(map::Beatmap) -> String

Get `map` in a human-readable format: Artist - Title [Diff].
"""
map_name(map::Beatmap) = "$(map.artist) - $(map.title) [$(map.diff)]"

"""
    mods_from_int(n::Int) -> Vector{Symbol}

Get a list of mods from `n`.
"""
function mods_from_int(n::Int)
    const order = [:EZ, :HD, :HT, :DT, :NC, :HR, :FL, :NF, :SD, :PF, :RL, :SO, :AP, :AT]
    mods = Symbol[]
    for (k, v) in reverse(sort(collect(mod_map); by=p -> p.second))
        if v <= n
            push!(mods, k)
            n -= v
            n <= 0 && return filter(m -> in(m, mods), order)
        end
    end
end

"""
    mods_from_string(s::AbstractString) -> Int

Get a number representation of the mods in `s`. This does not deal with the odd case of
mods separated by spaces.
"""
function mods_from_string(s::AbstractString)
    mods = 0
    s = uppercase(s[search(s, "]").stop + 1:end])
    idx = search(s, "+").stop + 1

    # The "easy case" is when there's a '+' before the mods.
    if idx != 0 && idx < length(s)
        s = s[idx:end]
        s = replace(split(s[findfirst(!isspace, s):end])[1], r"[^A-Z]", "")
        s = length(s) == 0 ? s : s[1:end-1]
        for idx in 1:2:length(s)
            mod = Symbol(s[idx:idx + 1])
            mods += get(mod_map, mod, 0)
        end
        return mods

    # This case is a lot more iffy.
    else
        for token in split(s)
            token = replace(token, r"[^A-Z]", "")
            length(token) % 2 != 0 && continue
            println(token)
            for idx in 1:2:length(token)
                mod = Symbol(token[idx:idx + 1])
                mods += get(mod_map, mod, 0)
            end
            mods > 0 && return mods
        end
    end
    return mods
end

function timestamp(s::Dates.Second)
    s = s.value
    h = convert(Int, floor(s / 3600))
    s -= 3600h
    m = floor(s / 60)
    s -= 60m
    m = format(convert(Int, m); width=2, zeropadding=true)
    s = format(convert(Int, s); width=2, zeropadding=true)
    return if h > 0
        "$h:$m:$s"
    else
        "$m:$s"
    end
end

function fmt(el::Union{Real, AbstractString})
    return if isa(el, AbstractFloat)
        round(el) == el ? string(convert(Int, round(el))) : string(trunc(el, 1))
    else
        el
    end
end
"""
    search(player::Player, map_str::AbstractString) -> Nullable{Beatmap}

Search `player`'s recent events and plays for a map called `map_str`.
"""
function search(player::Player, map_str::AbstractString)
    log("Searching $(length(player.events)) recent events")
    map = try
        beatmap(
            player.events[first(find(e -> e.map_str == map_str, player.events))].map_id,
        )
    catch e
        log(e)
        Nullable()
    end
    !isnull(map) && log("Found map: $(map_name(get(map)))") && return map

    log("Searching recent plays")
    recent = get(player_recent(player.id; lim=50), [])
    for map in (beatmap(play.map_id) for play in recent)
        isnull(map) && continue
        map_name(get(map)) == map_str && return map
    end
    # TODO: osusearch.
    log("No map found") && return nothing
end

"""
    build_comment(player::Player, beatmap::Beatmap) -> String

Build a comment from `player` and `beatmap`.
"""
function build_comment(player::Player, beatmap::Nullable{Beatmap})
    const osu = "https://osu.ppy.sh"
    buf = IOBuffer()
    tmp = ""

    if !isnull(beatmap)
        map = get(beatmap)
        tmp = "[$(map_name(map))]($osu/b/$(map.id)) [(↓)]($osu/d/$(map.id)) "
        tmp *= "by [$(map.mapper)]($osu/u/$(map.mapper))"
        Markdown.plain(buf, Markdown.Header(tmp, 3))
        tmp = ""
        plays = beatmap_scores(map.id)
        if !isnull(plays)
            top = get(plays)[1]
            # Output from `beatmap_scores` always has both `username` and `user_id` fields,
            # so we shouldn't need to handle `NullException`s.
            tmp = "#1: [$(get(top.username))]($osu/u/$(get(top.user_id))) ("
            if top.mods != mod_map[:NOMOD]
                tmp *= "+$(join(mods_from_int(top.mods))) - "
            end
            # `beatmap_scores` also always comes with `pp` set.
            tmp *= "$(trunc(top.accuracy, 2))% - "
            tmp *= "$(format(get(top.pp); commas=true))pp) || "
        end
        if isa(map, StdBeatmap)
            tmp *= "$(format(map.combo; commas=true))x max combo || "
        end
        tmp *= "$(map.status) ($(map.approved_date)) || "
        tmp *= "$(format(map.plays; commas=true)) plays"
        Markdown.plaininline(buf, Markdown.Bold(tmp))
        tmp = ""
    end

    return String(take!(buf))
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

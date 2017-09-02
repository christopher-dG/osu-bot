"""
Tools for parsing and formatting stuff, etc.
"""
module Utils

using Formatting

using OsuBot.OsuTypes
using OsuBot.Osu

export map_name, mods_from_int, mods_from_string, search, strfmt, timestamp

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
    return mods
end

mods_to_int(mods::Vector{Symbol}) = sum(map(m -> mod_map[m], mods))

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
        s = replace(split(first(s[findfirst(!isspace, s):end])), r"[^A-Z]", "")
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
    # We have no way to know what game mode we're looking for, so this won't work unless
    # unless it's standard.
    recent = get(player_recent(player.id; lim=50), [])
    for map in (beatmap(play.map_id) for play in recent)
        isnull(map) && continue
        map_name(get(map)) == map_str && return map
    end
    # TODO: osusearch.
    log("No map found") && return Nullable{Beatmap}()
end

function timestamp(s::Real)
    s = Int(round(s))
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

function strfmt(el::Real; precision::Int=1)
    return if round(el) == el || precision == 0
        format(round(el); commas=true)
    else
        format(trunc(el, precision); commas=true)
    end
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

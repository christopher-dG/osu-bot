"""
Tools for parsing and formatting stuff, etc.
"""
module Utils

using Formatting
using Mustache
using YAML

using OsuBot.OsuTypes
using OsuBot.Osu

import Base.search

export map_name, mods_from_int, mods_from_string, search, strfmt, timestamp, parse_player

const search_key = YAML.load(open(joinpath(dirname(@__DIR__), "config.yml")))["search_key"]
const search_url = "https://osusearch.com/api/search?key=$search_key&{{#:args}}{{.}}&{{/:args}}"
const order = [:EZ, :HD, :HT, :DT, :NC, :HR, :FL, :NF, :SD, :PF, :RL, :SO, :AP, :AT]
const map_regex = r"(.*) - (.*) \[(.*)\]"

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
    mods = Symbol[]
    for (k, v) in reverse(sort(collect(mod_map); by=p -> p.second))
        if v <= n
            push!(mods, k)
            n -= v
            n <= 0 && return filter(m -> in(m, mods), order)
        end
    end
    log("Found mods: $mods")
    return mods
end

"""
    mods_to_int(mods::Vector{Symbol}) -> Int

Get the integer associated with a list of mods.
"""
mods_to_int(mods::Vector{Symbol}) = sum(map(m -> mod_map[m], mods))

"""
    mods_from_string(s::AbstractString) -> Int

Get a number representation of the mods in `s`. This does not deal with the odd case of
mods separated by spaces. This should always be called on whole post title.
"""
function mods_from_string(s::AbstractString)
    mods = 0
    s = uppercase(s[search(s, "]").stop + 1:end])
    idx = search(s, "+").stop + 1

    # The "easy case" is when there's a '+' before the mods.
    if idx != 0 && idx < length(s)
        s = s[idx:end]
        s = replace(first(split(s[findfirst(!isspace, s):end])), r"[^A-Z]", "")
        if length(s) % 2 != 0
            # If this gets triggered, we're probably screwed.
            s = s[1:end-1]
        end
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
            for idx in 1:2:length(token)
                mod = Symbol(token[idx:idx + 1])
                mods += get(mod_map, mod, 0)
            end
            mods > 0 && return mods
        end
    end
    log("Found mods: $mods ($(mods_from_int(mods)))")
    return mods
end

"""
    search(
        player::Nullable{User},
        map_str::AbstractString
    ) -> Tuple{Nullable{Beatmap}, Nullable{Mode}}

Search for a map called `map_str`. If we find the map in `player`'s recent events, then
also return the game mode that it was played in (this helps deal with autoconverts).
"""
function search(player::Nullable{User}, map_str::AbstractString)
    if isnull(player)
        log("Searching for $map_str without a player")
    else
        log("Searching for $map_str with $(get(player).name)")

        # Player's recent events is the most reliable source.
        map, mode = search_events(get(player), map_str)
        if !isnull(map)
            return map, mode
        end

        # Player's recent plays is a bit more iffy.
        map = search_recent(get(player), map_str)
        if !isnull(map)
            return map, Nullable{Mode}()
        end
    end

    # osusearch.com is kind of a toss up.
    map = search_osusearch(map_str)
    return if !isnull(map)
        map, Nullable{Mode}()
    else
        Nullable{Beatmap}(), Nullable{Mode}()
    end
end

"""
    search_events(
        player::User,
        map_str::AbstractString
    ) -> Tuple{Nullable{<:Beatmap}, Nullable{Mode}}

Search `player`'s recent events for a play on `map_str`.
"""
function search_events(player::User, map_str::AbstractString)
    log("Searching $(length(player.events)) recent events")
    idx = findfirst(e -> uppercase(e.map_str) == uppercase(map_str), player.events)
    if idx != 0
        event = player.events[idx]
        map = try
            beatmap(event.map_id; mode=get(event.mode, nothing))
        catch e
            log(e)
            Nullable()
        end
        if !isnull(map)
            log("Found map: $(map_name(get(map))) with mode: $(get(event.mode, "null"))")
            return map, event.mode
        end
    end
    log("Couldn't find beatmap in recent events")
    return Nullable{Beatmap}(), Nullable{Mode}()
end

"""
    search_recent(player::User, map_str::AbstractString) -> Nullable{<:Beatmap}

Search `player`'s recent plays for a play on `map_str`.
"""
function search_recent(player::User, map_str::AbstractString)
    # We have no way to know what game mode we're looking for, so this won't work unless
    # unless it's standard.
    log("Searching $(player.name)'s recent plays")
    recent = get(player_recent(player.id; lim=50), Score[])
    # TODO: This duplicate elimination doesn't seem to be working.
    seen = []
    for play in recent
        in(play.map_id, seen) && continue
        map = beatmap(play.map_id)
        if !isnull(map)
            push!(seen, get(map).id)
            if uppercase(map_name(get(map))) == uppercase(map_str)
                return map
            end
        end
    end
    log("Couldn't find beatmap in recent plays")
    return Nullable{Beatmap}()
end

"""
    search_osusearch(map_str::AbstractString) -> Nullable{<:Beatmap}

Search osusearch.com for `map_str`.
"""
function search_osusearch(map_str::AbstractString)
    log("Searching osusearch.com")
    m = match(map_regex, map_str)
    if m == nothing
        log("map_str was not a well-formed map name: '$map_str'")
        return Nullable{Beatmap}()
    end

    artist, title, diff = m.captures
    args = ["title=$title", "artist=$artist", "diff_name=$diff"]
    url = replace(replace(render(search_url, args=args), " ", "+"), "&#x2F;", "/")

    maps = try
        Osu.request(url)["beatmaps"]
    catch
        log("Couldn't find beatmap on osusearch.com")
        return Nullable{Beatmap}()
    end
    filter!(
        m -> ==(
            uppercase("$(m["artist"]) - $(m["title"]) [$(m["difficulty_name"])]"),
            uppercase(map_str),
        ),
        maps,
    )

    if isempty(maps)
        log("Couldn't find beatmap on osusearch.com")
        return Nullable{Beatmap}()
    end

    fav = maps[indmax(map(m -> m["favorites"], maps))]
    return Nullable(make_map(Dict([pair.first => string(pair.second) for pair in fav])))
end

"""
    timestamp(s::Real) -> String

Convert `s` seconds into a timestamp.
"""
function timestamp(s::Real)
    s = max(s, 0)
    total = s
    s = Int(round(s))
    h = convert(Int, floor(s / 3600))
    s -= 3600h
    m = floor(s / 60)
    s -= 60m
    m = format(convert(Int, m); width=2, zeropadding=true)
    s = format(convert(Int, s); width=2, zeropadding=true)
    ts = if h > 0
        "$h:$m:$s"
    else
        "$m:$s"
    end
    log("Converted $total seconds to timestamp: $ts")
    return ts
end

"""
    strfmt(el::Real; precision::Int=1) -> String

Format `el` with arbitary precision and comma separation.
"""
function strfmt(el::Real; precision::Int=1)
    return if round(el) == el || precision == 0
        format(round(el); commas=true)
    else
        format(trunc(el, precision); commas=true)
    end
end

"""
    parse_player(s::AbstractString) -> String

Get a player name from the beginning part of a post title, cutting out common mistakes.
This should only be run on the part of a title up to and not including the first '|'.
"""
function parse_player(s::AbstractString)
    s = strip(s)
    for cap in matchall(r"(\([^\(^\)]*\))", s)
        range = search(s, cap)
        if range.start == 1
            log("Stripping $cap from $s")
            s = strip(s[range.stop + 1:end])
        elseif range.stop != -1
            # This covers the common "Player (something)" case, and it also partially takes
            # care of weird cases with parens in the middle by just assuming that the
            # leftmost part is the player name.
            log("Stripping $cap from $s")
            s = strip(s[1:range.start - 1])
        end
    end

    # Usernames can have brackets but people tend to put auxilary information in them
    # before the player name, i.e. "[Unnoticed] Player | ...".
    ignores =  [
        "UNNOTICED",
        "STANDARD",
        "STD",
        "O!STD",
        "OSU!STD",
        "CTB",
        "O!CATCH",
        "OSU!CTB",
        "O!CTB",
        "MANIA",
        "O!MANIA",
        "OSU!MANIA",
        "OSU!M",
        "O!M",
        "TAIKO",
        "OSU!TAIKO",
        "O!TAIKO",
    ]
    for cap in matchall(r"(\[[^\[^\]]*\])", s)
        if in(replace(uppercase(cap), " ", "")[2:end-1], ignores)
            range = search(s, cap)
            if range.start == 1
                log("Stripping $cap from $s")
                s = strip(s[range.stop + 1:end])
            elseif range.stop == length(s)
                log("Stripping $cap from $s")
                s = strip(s[1:range.start - 1])
            end
        end
    end
    log("Player name: $s")
    return s
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

"""
Interface for interacting with the osu! API.
"""
module Osu  # It's too bad calling this 'osu!' breaks so many naming conventions.

using HTTP
using Mustache
using YAML

using OsuBot.OsuTypes

const osu_key = YAML.load(open(joinpath(dirname(@__DIR__), "config.yml")))["osu_key"]
const osu_url = "https://osu.ppy.sh/api/{{:cmd}}?k=$osu_key&{{#:args}}{{.}}&{{/:args}}"

"""
    beatmap(id::Int) -> Nullable{Beatmap}

Get a beatmap by `id`.
"""
function beatmap(id::Int)
    args = ["b=$id", "limit=1"]
    url = render(osu_url; cmd="get_beatmaps", args=args)
    return Nullable{Beatmap}(try Beatmap(request(url)[1]) catch end)
end

"""
    mapset(id::Int) -> Nullable{Vector{Beatmap}}

Get maps in a mapset by `id`.
"""
function mapset(id::Int; lim::Int=500)
    args=["s=id", "limit=$lim"]
    url = render(osu_url; cmd="get_beatmaps", args=args)
    return Nullable{Vector{Beatmap}}(try map(b -> Beatmap(b), request(url)) catch end)
end

"""
    player(id::Int, mode::Mode=STD) -> Nullable{Player}

Get a player by `id`.
"""
function player(id::Int; mode::Mode=STD)
    args = ["u=$id", "type=id", "m=$(Int(mode))"]
    url = render(osu_url; cmd="get_user", args=args)
    return Nullable{Player}(try Player(request(url)[1]) catch end)
end

"""
    player(name::AbstractString, mode::Mode=STD) -> Nullable{Player}

Get a player by `name`.
"""
function player(name::AbstractString; mode::Mode=STD)
    args = ["u=$name", "type=string", "m=$(Int(mode))"]
    url = render(osu_url; cmd="get_user", args=args)
    return Nullable{Player}(try Player(request(url)[1]) catch end)
end

"""
    beatmap_scores(
        id::Int;
        mode::Mode=STD,
        mods::Union{Int, Void}=nothing,
        lim::Int=50,
    ) -> Nullable{Vector{Score}}

Get the top scores on a map by `id`.
"""
function beatmap_scores(
    id::Int;
    mode::Mode=STD,
    mods::Union{Int, Void}=nothing,
    lim::Int=50,
)
    args = ["b=$id", "m=$(Int(mode))", "limit=$lim"]
    isa(mods, Int) && push!(args, "mods=$mods")
    url = render(osu_url; cmd="get_scores", args=args)
    return Nullable{Vector{Score}}(try map(s -> Score(s), request(url)) catch end)
end

"""
    beatmap_scores(
        id::Int,
        player::Int;
        mode::Mode=STD,
        mods::Union{Int, Void}=nothing,
        lim::Int=50,
    ) -> Nullable{Vector{Score}}

Get `player` (by id)'s' top scores on a map by `id`.
"""
function beatmap_scores(
    id::Int,
    player::Int;
    mode::Mode=STD,
    mods::Union{Int, Void}=nothing,
    lim::Int=50,
)
    args = ["b=$id", "u=$player", "type=id", "m=$(Int(mode))", "mods=$mods", "limit=$lim"]
    url = render(osu_url; cmd="get_scores", args=args)
    return Nullable{Vector{Score}}(try map(s -> Score(s), request(url))catch end)
end

"""
    beatmap_scores(
        id::Int,
        player::AbstractString;
        mode::Mode=STD,
        mods::Union{Int, Void}=nothing,
        lim::Int=50,
    ) -> Nullable{Vector{Score}}

Get `player` (by username)'s top scores on a map by `id`.
"""
function beatmap_scores(
    id::Int,
    player::AbstractString;
    mode::Mode=STD,
    mods::Union{Int, Void}=nothing,
    lim::Int=50,
)
    args = ["b=$id", "u=$player", "m=$(Int(mode))", "type=string", "limit=$lim"]
    url = render(osu_url; cmd="get_scores", args=args)
    return Nullable{Vector{Score}}(try map(s -> Score(s), request(url)) catch end)
end

"""
    player_recent(id::Int; mode::Mode=STD, lim::int=10)

Get a player (by `id`)'s recent scores.
"""
function player_recent(id::Int; mode::Mode=STD, lim::Int=10)
    args = ["u=$id", "type=id", "m=$(Int(mode))", "limit=$lim"]
    url = render(osu_url; cmd="get_user_recent", args=args)
    return Nullable{Vector{Score}}(try map(s -> Score(s), request(url)) catch end)
end

"""
    player_recent(name::AbstractString; mode::Mode=STD, lim::int=10)

Get a player (by `name`)'s recent scores.
"""
function player_recent(name::AbstractString; mode::Mode=STD, lim::Int=10)
    args = ["u=$id", "type=string", "m=$(Int(mode))", "limit=$lim"]
    url = render(osu_url; cmd="get_user_recent", args=args)
    return Nullable{Vector{Score}}(try map(s -> Score(s), request(url)) catch end)
end

"""
    player_best(id::Int; mode::Mode=STD, lim::Int=10)

Get a player (by `id`)'s best scores.
"""
function player_best(id::Int; mode::Mode=STD, lim::Int=10)
    args = ["u=$id", "type=id", "m=$(Int(mode))", "limit=$lim"]
    url = render(osu_url; cmd="get_user_best", args=args)
    return Nullable{Vector{Score}}(try map(s -> Score(s), request(url)) catch end)
end

"""
    player_best(name::AbstractString; mode::Mode=STD, lim::Int=10)

Get a player (by `name`)'s best scores.
"""
function player_best(name::AbstractString; mode::Mode=STD, lim::Int=10)
    args = ["u=$name", "type=string", "m=$(Int(mode))", "limit=$lim"]
    url = render(osu_url; cmd="get_user_best", args=args)
    return Nullable{Vector{Score}}(try map(s -> Score(s), request(url)) catch end)
end

"""
    request(url::AbstractString) -> Vector

Request some data from `url`. Returns a list of JSON objects or throws an error.
"""
function request(url::AbstractString)
    log("Making request to $(replace(url, osu_key, "[secure]"))")
    try
        response = HTTP.get(url)
    catch err
        log(err.msg)
        rethrow(err)
    end
    return if response.status == 200
        JSON.parse(readstring(response.body))
    else
        log("Error code $(response.status) from server")
        error()
    end
end

log(msg::AbstractString) = info("$(basename(@__FILE__)): $msg")

end

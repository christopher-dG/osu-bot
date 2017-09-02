"""
Methods for interacting with the osu! API.
"""
module Osu

using HTTP
using JSON
using Mustache
using YAML

using OsuBot.OsuTypes

export beatmap, mapset, player, beatmap_scores, player_recent, player_best

const osu_key = YAML.load(open(joinpath(dirname(@__DIR__), "config.yml")))["osu_key"]
const osu_url = "https://osu.ppy.sh/api/{{:cmd}}?k=$osu_key&{{#:args}}{{.}}&{{/:args}}"

"""
    beatmap(id::Int) -> Nullable{Beatmap}

Get a beatmap by `id`.
"""
function beatmap(id::Int)
    args = ["b=$id", "limit=1"]
    url = render(osu_url; cmd="get_beatmaps", args=args)
    return Nullable{Beatmap}(try make_map(first(request(url))) catch end)
end

"""
    mapset(id::Int) -> Nullable{Vector{Beatmap}}

Get maps in a mapset by `id`.
"""
function mapset(id::Int; lim::Int=500)
    args=["s=$id", "limit=$lim"]
    url = render(osu_url; cmd="get_beatmaps", args=args)
    return Nullable{Vector{Beatmap}}(try make_map.(request(url)) catch end)
end

"""
    player(id::Int, mode::Mode=OsuTypes.STD) -> Nullable{Player}

Get a player by `id`.
"""
function player(id::Int; mode::Mode=OsuTypes.STD)
    args = ["u=$id", "type=id", "m=$(Int(mode))", "event_days=31"]
    url = render(osu_url; cmd="get_user", args=args)
    return Nullable{Player}(try Player(first(request(url))) catch e rethrow(e) end)
end

"""
    player(name::AbstractString, mode::Mode=OsuTypes.STD) -> Nullable{Player}

Get a player by `name`.
"""
function player(name::AbstractString; mode::Mode=OsuTypes.STD)
    args = ["u=$name", "type=string", "m=$(Int(mode))", "event_days=31"]
    url = render(osu_url; cmd="get_user", args=args)
    return Nullable{Player}(try Player(first(request(url))) catch end)
end

"""
    beatmap_scores(
        id::Int;
        mode::Mode=OsuTypes.STD,
        mods::Int=mod_map[:FREEMOD],
        lim::Int=50,
    ) -> Nullable{Vector{Score}}

Get the top scores on a map by `id`.
"""
function beatmap_scores(
    id::Int;
    mode::Mode=OsuTypes.STD,
    mods::Int=mod_map[:FREEMOD],
    lim::Int=50,
)
    args = ["b=$id", "m=$(Int(mode))", "limit=$lim"]
    mods != mod_map[:FREEMOD] && push!(args, "mods=$mods")
    url = render(osu_url; cmd="get_scores", args=args)
    return Nullable{Vector{Score}}(
        try
            Score.(merge.(request(url), Dict("beatmap_id" => string(id), "mode" => mode)))
        catch
        end
    )
end

"""
    beatmap_scores(
        id::Int,
        player::Int;
        mode::Mode=OsuTypes.STD,
        mods::Int=mod_map[:FREEMOD],
        lim::Int=50,
    ) -> Nullable{Vector{Score}}

Get `player` (by id)'s' top scores on a map by `id`.
"""
function beatmap_scores(
    id::Int,
    player::Int;
    mode::Mode=OsuTypes.STD,
    mods::Int=mod_map[:FREEMOD],
    lim::Int=50,
)
    args = ["b=$id", "u=$player", "type=id", "m=$(Int(mode))", "limit=$lim"]
    mods != mod_map[:FREEMOD] && push!(args, "mods=$mods")
    url = render(osu_url; cmd="get_scores", args=args)
    return Nullable{Vector{Score}}(
        try
             Score.(merge.(request(url), Dict("beatmap_id" => string(id), "mode" => mode)))
        catch
        end,
    )
end

"""
    beatmap_scores(
        id::Int,
        player::AbstractString;
        mode::Mode=OsuTypes.STD,
        mods::Int=mod_map[:FREEMOD],
        lim::Int=50,
    ) -> Nullable{Vector{Score}}

Get `player` (by username)'s top scores on a map by `id`.
"""
function beatmap_scores(
    id::Int,
    player::AbstractString;
    mode::Mode=OsuTypes.STD,
    mods::Int=mod_map[:FREEMOD],
    lim::Int=50,
)
    args = ["b=$id", "u=$player", "m=$(Int(mode))", "type=string", "limit=$lim"]
    mods != mod_map[:FREEMOD] && push!(args, "mods=$mods")
    url = render(osu_url; cmd="get_scores", args=args)
    return Nullable{Vector{Score}}(
        try
            Score.(merge.(request(url), Dict("beatmap_id" => string(id), "mode" => mode)))
        catch
        end,
    )
end

"""
    player_recent(id::Int; mode::Mode=OsuTypes.STD, lim::int=10) -> Nullable{Vector{Score}}

Get a player (by `id`)'s recent scores.
"""
function player_recent(id::Int; mode::Mode=OsuTypes.STD, lim::Int=10)
    args = ["u=$id", "type=id", "m=$(Int(mode))", "limit=$lim"]
    url = render(osu_url; cmd="get_user_recent", args=args)
    return Nullable{Vector{Score}}(
        try Score.(merge.(request(url), Dict("mode" => mode))) catch end,
    )
end

"""
    player_recent(
        name::AbstractString;
        mode::Mode=OsuTypes.STD,
        lim::int=10
    ) -> Nullable{Vector{Score}}date"], fmt),

Get a player (by `name`)'s recent scores.
"""
function player_recent(name::AbstractString; mode::Mode=OsuTypes.STD, lim::Int=10)
    args = ["u=$name", "type=string", "m=$(Int(mode))", "limit=$lim"]
    url = render(osu_url; cmd="get_user_recent", args=args)
    return Nullable{Vector{Score}}(
        try
            Score.(merge.(
                request(url),
                Dict("username" => name, "mode" => mode),
            ))
        catch
        end,
    )
end

"""
    player_best(id::Int; mode::Mode=OsuTypes.STD, lim::Int=10)

Get a player (by `id`)'s best scores.
"""
function player_best(id::Int; mode::Mode=OsuTypes.STD, lim::Int=10)
    args = ["u=$id", "type=id", "m=$(Int(mode))", "limit=$lim"]
    url = render(osu_url; cmd="get_user_best", args=args)
    return Nullable{Vector{Score}}(
        try Score.(merge.(request(url), Dict("mode" => mode))) catch end,
    )
end

"""
    player_best(name::AbstractString; mode::Mode=OsuTypes.STD, lim::Int=10)

Get a player (by `name`)'s best scores.
"""
function player_best(name::AbstractString; mode::Mode=OsuTypes.STD, lim::Int=10)
    args = ["u=$name", "type=string", "m=$(Int(mode))", "limit=$lim"]
    url = render(osu_url; cmd="get_user_best", args=args)
    return Nullable{Vector{Score}}(
        try
             Score.(merge.(request(url), Dict("username" => name, "mode" => mode)))
        catch
        end,
    )
end

"""
    request(url::AbstractString) -> Vector

Request some data from `url`. Returns a list of JSON objects or throws an error.
"""
function request(url::AbstractString)
    if endswith(url, "&")
        url = url[1:end-1]
    end
    url = replace(url, " ", "%20")
    log("Making request to $(replace(url, osu_key, "[secure]"))")
    response = nothing
    for i in 1:3
        i > 1 && log("Attempt $i...") && sleep(3)
        response = try
            HTTP.get(url)
        catch err
            log(err)
            nothing
        end
        response != nothing && response.body.len > 50 && break
    end
    if response == nothing
        log("No response from server") && error()
    elseif response.status != 200
        log("Error code $(response.status) from server") && error()
    elseif response.body.len < 50
        log("Empty response from server") && error()
    end
    return JSON.parse(String(take!(response)))
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

"""
Wrapper around basic oppai functionality.
"""
module Oppai

using HTTP
using JSON

using OsuBot.OsuTypes
using OsuBot.Utils

export get_diff, get_pp

const tmpdir = joinpath(tempdir(), "osubot")
!isdir(tmpdir) && mkdir(tmpdir)

"""
    download(id::Int) -> String

Save a map by `id`'s `.osu` file to and return a path to the file. Returns an empty string
on failure.
"""
function download(id::Int)
    path = joinpath(tmpdir, "$id.osu")
    if isfile(path)
        log("File already exists at $path; reusing")
        return path
    end
    url = "https://osu.ppy.sh/osu/$id"
    log("Downloading $id.osu to $(dirname(path)) from $url")
    try
        body = HTTP.request(url).body
        write(path, body)
        return path
    catch e
        log(e)
        return ""
    end
end

"""
    oppai(cmd::Cmd) -> Dict

Run `cmd` and return its output as a `Dict`.
"""
function oppai(cmd::Cmd)
    log("Running $cmd")
    return JSON.parse(readstring(cmd))
end

"""
    get_pp(map::Beatmap, acc::Real, [mods::Int]; taiko::Bool=false) -> Union{Dict, Void}

Calculate pp for a beatmap. Returns `nothing` on failure.
"""
function get_pp(map::Beatmap, acc::Real; taiko::Bool=false)
    return get_pp(map, acc, mod_map[:NOMOD]; taiko=taiko)
end

function get_pp(map::Beatmap, acc::Real, mods::Int; taiko::Bool=false)
    path = download(map.id)
    isempty(path) && return nothing
    mods = mods_from_int(mods)
    mods = isempty(mods) ? "" : "+$(join(mods))"
    taiko = taiko || isa(map, TaikoBeatmap) ? "-taiko" : ""
    cmd = `oppai $path -ojson $acc% $mods $taiko`
    return try
        oppai(cmd)["pp"]
    catch e
        log("oppai failed: $e")
        rm(path)
        nothing
    end
end

get_pp(::OtherBeatmap, acc::Real) = nothing

get_pp(::OtherBeatmap, acc::Real, mods::Int) = nothing

"""
    get_diff(beatmap::Beatmap, [mods::Int]) -> Union{Dict, Void}

Calculate difficulty values for a beatmap. Returns `nothing` on failure.
"""
function get_diff(beatmap::Beatmap)
    return Dict{Symbol, Union{AbstractString, Real}}(
        :AR => beatmap.ar,
        :CS => beatmap.cs,
        :HP => beatmap.hp,
        :OD => beatmap.od,
        :SR => beatmap.stars,
        :BPM => beatmap.bpm,
        :LEN => Utils.timestamp(beatmap.length.value),
    )
end

function get_diff(beatmap::Beatmap, mods::Int)
    isa(beatmap, OtherBeatmap) && mods != mod_map[:NOMOD] && return nothing
    mods == mod_map[:NOMOD] && return get_diff(beatmap)

    path = download(beatmap.id)
    isempty(path) && return nothing
    mods = mods_from_int(mods)
    speed = if any(m -> in(m, mods), [:DT, :NC])
        1.5
    elseif in(:HT, mods)
        0.66
    else
        1.0
    end
    mods = isempty(mods) ? "" : "+$(join(mods))"
    taiko = isa(beatmap, TaikoBeatmap) ? "-taiko" : ""
    cmd = `oppai $path -ojson $mods $taiko`
    d = oppai(cmd)
    return Dict{Symbol, Union{AbstractString, Real}}(
        :AR => d["ar"],
        :CS => d["cs"],
        :HP => d["hp"],
        :OD => d["od"],
        :SR => d["stars"],
        :BPM => speed * beatmap.bpm,
        :LEN => Utils.timestamp(beatmap.length.value / speed),
    )
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

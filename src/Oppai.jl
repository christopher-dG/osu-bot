"""
Wrapper around basic oppai functionality.
"""
module Oppai

using HTTP
using JSON

using OsuBot.OsuTypes
using OsuBot.Utils

const tmpdir = joinpath(tempdir(), "osubot")
mkpath(tmpdir)

"""
    download(id::Int) -> String

Save a map by `id`'s `.osu` file to and return a path to the file. Returns an empty string
on failure.
"""
function download(id::Int)
    path = joinpath(tmpdir, "$id.osu")
    if isfile(path)
        warn("File already exists at $path; reusing")
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

function oppai(cmd::Cmd)
    log("Running $cmd")
    return JSON.parse(readstring(cmd))
end

get_pp(beatmap::Beatmap, acc::AbstractFloat) = get_pp(beatmap, acc, mod_map[:NOMOD])

function get_pp(beatmap::Beatmap, acc::AbstractFloat, mods::Int)
    path = download(beatmap.id)
    isempty(path) && return nothing
    mods = mods_from_int(mods)
    mods = isempty(mods) ? "" : "+$(join(mods))"
    taiko = isa(beatmap, TaikoBeatmap) ? "-taiko" : ""
    cmd = `$oppai_cmd $path -ojson $acc% $mods $taiko`
    return try
        oppai(cmd)["pp"]
    catch
        nothing
    end
end

get_pp(::OtherBeatmap, acc::AbstractFloat) = nothing

get_pp(::OtherBeatmap, acc::AbstractFloat, mods::Int) = nothing

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

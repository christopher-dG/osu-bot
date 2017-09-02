"""
Wrapper around basic oppai functionality.
"""
module Oppai

using HTTP

using OsuBot.OsuTypes

"""
    download(id::Int) -> Bool

Write a map by `id`'s `.osu` file to `map.osu`, and return true on success.
"""
function download(id::Int)
    url = "https://osu.ppy.sh/osu/$id"
    log("Downloading from $url")
    return try
        write("map.osu", HTTP.request(url).body)
        true
    catch e
        log(e)
        false
    end
end

function get_pp(beatmap::Beatmap; mods::Int=mod_map[:FREEMOD])
end

get_pp(::OtherBeatmap) = nothing

function get_diff(beatmap::Beatmap; mods::Int=mod_map[:FREEMOD])
    isa(beatmap, OtherBeatmap) && mods != mod_map[:FREEMOD] && return nothing
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

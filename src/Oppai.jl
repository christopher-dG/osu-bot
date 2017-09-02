"""
Wrapper around basic oppai functionality. Revolves around global variables, so results can
be found in `Oppai.map_stats` and `Oppai.pp` after calls to `run`.

"""
module Oppai

using HTTP

using OsuBot.OsuTypes

struct Object
    time::Cdouble
    obj_type::Cuchar
    data_off::Ptr{Void}
    normpos::NTuple{2, Cdouble}
    strains::NTuple{2, Cdouble}
    is_single::Cint
end

struct Timing
    time::Cdouble
    ms_per_beat::Cdouble
    change::Cint
end

struct Beatmap
    mode::Cint
    title::Cstring
    title_unicode::Cstring
    artist::Cstring
    artist_unicode::Cstring
    creator::Cstring
    version::Cstring
    objects::Ptr{Object}
    nobjects::Cint
    timing_points::Ptr{Timing}
    ntiming_points::Cint
    ncircles::Cushort
    nsliders::Cushort
    nspinners::Cushort
    hp::Cfloat
    cs::Cfloat
    od::Cfloat
    ar::Cfloat
    sv::Cfloat
    tick_rate::Cfloat
end

struct Slice
    start::Ptr{Cchar}
    stop::Ptr{Cchar}
end

struct Memstack
    buf::Ptr{Cchar}
    top::Cint
    size::Cint
end

struct Parser
    lastpos::Slice
    lastline::Slice
    buf::NTuple{65536, Cchar}
    title::Cint
    title_unicode::Cint
    artist::Cint
    artist_unicode::Cint
    creator::Cint
    version::Cint
    section::NTuple{64, Cchar}
    strings::Memstack
    timing::Memstack
    objects::Memstack
    object_data::Memstack
    b::Ptr{Beatmap}
end

struct DiffCalc
    highest_strains::Memstack
    b::Ptr{Beatmap}
    singletap_threshold::Cdouble
    total::Cdouble
    aim::Cdouble
    speed::Cdouble
    nsingles::Cushort
    nsingles_threshold::Cushort
end

struct PPCalc
    total::Cdouble
    aim::Cdouble
    speed::Cdouble
    acc::Cdouble
    accuracy::Cdouble
end

struct PPParams
    aim::Cdouble
    speed::Cdouble
    base_ar::Cfloat
    base_od::Cfloat
    max_combo::Cint
    nsliders::Cushort
    ncircles::Cushort
    nobjects::Cushort
    mode::Cuint
    mods::Cuint
    combo::Cint
    n300::Cushort
    n100::Cushort
    n50::Cushort
    nmiss::Cushort
    score_version::Cint
end

struct BeatmapStats
    ar::Cfloat
    od::Cfloat
    cs::Cfloat
    hp::Cfloat
    speed::Cfloat
end

function init()
    oppai = Libdl.dlopen("liboppai")
    global d_init = Libdl.dlsym(oppai, :d_init)
    global p_init = Libdl.dlsym(oppai, :p_init)
    global pp_init = Libdl.dlsym(oppai, :pp_init)
    global p_map = Libdl.dlsym(oppai, :p_map)
    global d_calc = Libdl.dlsym(oppai, :d_calc)
    global b_ppv2p = Libdl.dlsym(oppai, :b_ppv2p)
    global ppv2p = Libdl.dlsym(oppai, :ppv2p)
    global acc_round = Libdl.dlsym(oppai, :acc_round)
    global mods_apply = Libdl.dlsym(oppai, :mods_apply)
    global beatmap = Ref{Beatmap}()
    global calc = Ref{DiffCalc}()
    global pp = Ref{PPCalc}()
    global params = Ref{PPParams}()
    global parser = Ref{Parser}()
    global map_stats = Ref{BeatmapStats}()
    global mods = Cint(mod_map[:NOMOD])
    r = ccall(d_init, Cint, (Ref{DiffCalc},), calc)
    r != 0 && log("ccall to d_init returned $r") && return false
    ccall(pp_init, Void, (Ref{PPParams},), params)
    r = ccall(p_init, Cint, (Ref{Parser},), parser)
    r != 0 && log("ccall to p_init returned $r") && return false
    return true
end

"""
    change_aim_speed(aim::Cfloat, speed:Cfloat) -> Void

Replace the global `params` with a new instance containng different values for `aim` and
`speed`.
"""
function change_aim_speed(aim, speed)
    old = params[]
    global params = Ref{PPParams}(PPParams(
        aim, speed, old.base_ar, old.base_od, old.max_combo, old.nsliders, old.ncircles, old.nobjects,
        old.mode, old.mods, old.combo, old.n300, old.n100, old.n50, old.nmiss, old.score_version,
    ))
    return nothing
end

"""
    change_counts(n300::Cushort, n100:Cushort, n50::Cushort) -> Void

Replace the global `params` with a new instance containng different values for hit counts.
"""
function change_counts(n300::Cushort, n100::Cushort, n50::Cushort)
    old = params[]
    global params = Ref{PPParams}(PPParams(
        old.aim, old.speed, old.base_ar, old.base_od, old.max_combo, old.nsliders, old.ncircles, old.nobjects,
        old.mode, old.mods, old.combo, n300, n100, n50, old.nmiss, old.score_version,
    ))
    return nothing
end

"""
    apply_mods(mods::Cuint) -> Bool

Apply mods, and replace the global `params` with a new instance containng the new mods.
"""
function apply_mods(mods::Cuint)
    # ~0 means apply all mods.
    ccall(mods_apply, Void, (Cuint, Ref{BeatmapStats}, Cuint), mods, map_stats, ~Cuint(0))
    old = params[]
    global params = Ref{PPParams}(PPParams(
        old.aim, old.speed, old.base_ar, old.base_od, old.max_combo, old.nsliders, old.ncircles, old.nobjects,
        old.mode, mods, old.combo, old.n300, old.n100, old.n50, old.nmiss, old.score_version,
    ))
    return true
end

"""
    load_map(file::AbstractString) -> Bool

Load the map at `file`.
"""
function load_map(file::AbstractString)
    fp = ccall(:fopen, Cptrdiff_t, (Cstring, Cstring), file, "r")
    fp == C_NULL && log("ccall to fopen returned NULL")
    r = ccall(p_map, Cint, (Ref{Parser}, Ref{Beatmap}, Cptrdiff_t), parser, beatmap, fp)
    r < 0 && log("ccall to p_map returned $r") && return false
    global map_stats = Ref{BeatmapStats}(
        BeatmapStats(beatmap[].ar, beatmap[].od, beatmap[].cs, beatmap[].hp, Cfloat(1.0)),
    )
    r = ccall(:fclose, Cint, (Cptrdiff_t,), fp)
    r != 0 && log("ccall to fclose returned $r") && return false
    return true
end

"""
    load_map() -> Void
Load the default map file, which should be obtained with `download`.
"""
load_map() = load_map("map.osu")

"""
    run(; acc::Float64=100.0, mods::Int=mod_map[:NOMOD]) -> Bool

Run oppai on the currently loaded map.
"""
function run(; acc::Float64=100.0, mods::Int=mod_map[:NOMOD])
    load_map()
    # Calculate map values like AR, OD, max combo, etc.
    r = ccall(d_calc, Cint, (Ref{DiffCalc}, Ref{Beatmap}, Cint), calc, beatmap, mods)
    r != 0 &&  log("ccall to d_calc returned $r") && return false
    # We have to manually set these two values, which we just got from the above call.
    change_aim_speed(calc[].aim, calc[].speed)
    # Set the required values in params to the map's values.
    r = ccall(
        b_ppv2p, Cint, (Ref{Beatmap}, Ref{PPCalc}, Ref{PPParams}), beatmap, pp, params,
    )
    r != 0 &&  log("ccall to b_ppv2p returned $r") && return false
    # Set the accuracy to the desired value... In a very clunky way.
    n300 = Ref{Cushort}(params[].n300)
    n100 = Ref{Cushort}(params[].n100)
    n50 = Ref{Cushort}(params[].n50)
    ccall(
        acc_round,
        Void,
        (Cdouble, Cushort, Cushort, Ref{Cushort}, Ref{Cushort}, Ref{Cushort}),
        acc, params[].nobjects, params[].nmiss,
        n300, n100, n50,
    )
    change_counts(n300[], n100[], n50[])
    apply_mods(Cuint(mods))
    # Finally, calculate pp.
    r = ccall(ppv2p, Cint, (Ref{PPCalc}, Ref{PPParams}), pp, params)
    r != 0 &&  log("ccall to ppv2p returned $r") && return false
    return true
end

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

"""
    getpp() -> Float64

Get the currently calculated pp value.
"""
getpp() = pp[].total

"""
    getdiff() -> Dict{String, Float64}

Get the current calculated difficulty values.
"""
function getdiff()
    return Dict{Symbol, AbstractFloat}(
        :AR => map_stats[].ar,
        :OD => map_stats[].od,
        :CS => map_stats[].cs,
        :HP => map_stats[].hp,
        :SR => calc[].total,
        :SPD => map_stats[].speed,
    )
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

"""
Wrapper around basic oppai functionality. Revolves around global variables, so results can
be found in `Oppai.map_stats` and `Oppai.pp` after calls to `run`.

"""
module Oppai

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
    global map = Ref{Beatmap}()
    global calc = Ref{DiffCalc}()
    global pp = Ref{PPCalc}()
    global params = Ref{PPParams}()
    global parser = Ref{Parser}()
    global map_stats = Ref{BeatmapStats}()
    global mods = Cint(OsuTypes.NOMOD)
    ccall(d_init, Cint, (Ref{DiffCalc},), calc)
    ccall(pp_init, Cint, (Ref{PPParams},), params)
    ccall(p_init, Cint, (Ref{Parser},), parser)
    return nothing
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
    apply_mods(mods::Cushort) -> Void

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
    return nothing
end

function load_map(file::AbstractString)
    fp = ccall(:fopen, Cptrdiff_t, (Cstring, Cstring), file, "r")
    ccall(p_map, Cint, (Ref{Parser}, Ref{Beatmap}, Cptrdiff_t), parser, map, fp)
    global map_stats = Ref{BeatmapStats}(
        BeatmapStats(map[].ar, map[].od, map[].cs, map[].hp, Cfloat(1.0)),
    )
    ccall(:fclose, Cint, (Cptrdiff_t,), fp)
    return nothing
end

"""
    run(; acc::Float64=100.0, mods::Int=Int(OsuTypes.NOMOD)) -> Void

Run oppai on the currently loaded map.
"""
function run(; acc::Float64=100.0, mods::Int=Int(OsuTypes.NOMOD))
    # Calculate map values like AR, OD, max combo, etc.
    ccall(d_calc, Cint, (Ref{DiffCalc}, Ref{Beatmap}, Cint), calc, map, mods)
    # We have to manually set these two values, which we just got from the above call.
    change_aim_speed(calc[].aim, calc[].speed)
    # Set the required values in params to the map's values.
    ccall(b_ppv2p, Cint, (Ref{Beatmap}, Ref{PPCalc}, Ref{PPParams}), map, pp, params)
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
    ccall(ppv2p, Cint, (Ref{PPCalc}, Ref{PPParams}), pp, params)
    return nothing
end

end

"""
Types that represent concepts/objects in osu!.
"""
module OsuTypes

export make_map, Beatmap, Player, Score, Mode, Mod

const fmt = DateFormat("y-m-d H:M:S")

@enum Status GRAVEYARD=-2 WIP PENDING RANKED APPROVED QUALIFIED LOVED

@enum Mode STD TAIKO CTB MANIA

# https://github.com/ppy/osu-api/wiki#mods
@enum(
    Mod,
    NOMOD=1 >> 1,
    NF=1 << 0,
    EZ=1 << 1,
    NOVID=1 << 2,
    HD=1 << 3,
    HR= 1 << 4,
    SD=1 << 5,
    DT=1 << 6,
    RL=1 << 7,
    HT=1 << 8,
    NC=1 << 6 + 1 << 9,  # DT is always set along with NC.
    FL=1 << 10,
    AT=1 << 11,
    SO=1 << 12,
    AP=1 << 13,
    PF=1 << 5 + 1 << 14,  # SD is always set along with PF.
    K4=1 << 15,
    K5=1 << 16,
    K6=1 << 17,
    K7=1 << 18,
    K8=1 << 19,
    KMOD=1 << 15 | 1 << 16 | 1 << 17 | 1 << 18 | 1 << 19,
    FADEIN=1 << 20,
    RANDOM=1 << 21,
    LAST=1 << 22,
    FREEMOD=1 << 0 | 1 << 1 | 1 << 3 | 1 << 4 | 1 << 5 | 1 << 10 | 1 << 20 | 1 << 7 | 1 << 11 | 1 << 12 | 1 << 15 | 1 << 16 | 1 << 17 | 1 << 18 | 1 << 19,
    K9=1 << 24,
    K10=1 << 25,
    K1=1 << 26,
    K3=1 << 27,
    K2=1 << 28,
)

"""
    A beatmap of any mode.
"""
abstract type Beatmap end

"""
An osu!std beatmap.
"""
struct StdBeatmap <: Beatmap
    id::Int  # Beatmap ID.
    set_id::Int  # Beatmapset ID.
    artist::AbstractString  # Song artist.
    title::AbstractString  # Song title.
    diff::AbstractString  # Diff name.
    mapper::AbstractString  # Mapper name.
    stars::Float16  # Star rating.
    cs::Float16  # Circle size.
    od::Float16  # Overall difficulty.
    ar::Float16  # Approach rate.
    hp::Float16  # HP drain.
    bpm::Float16  # Song BPM.
    length::Dates.Second  # Song length.
    status::Status  # Ranked status.
    approved_date::DateTime  # Date and time ranked/loved/qualified.
    last_update::DateTime  # Date and time last updated.
    plays::Int  # Play count.
    combo::Int  # Max combo.

    function StdBeatmap(d::Dict)
        new(
            parse(Int, d["beatmap_id"]),
            parse(Int, d["beatmapset_id"]),
            d["artist"],
            d["title"],
            d["version"],
            d["creator"],
            parse(Float16, d["difficultyrating"]),
            parse(Float16, d["diff_size"]),
            parse(Float16, d["diff_overall"]),
            parse(Float16, d["diff_approach"]),
            parse(Float16, d["diff_drain"]),
            parse(Float16, d["bpm"]),
            Dates.Second(d["total_length"]),
            Status[parse(Int, d["approved"])][1],
            DateTime(d["approved_date"], fmt),
            DateTime(d["last_update"], fmt),
            parse(Int, d["playcount"]),
            parse(Int, d["max_combo"]),
        )
    end
end

"""
An beatmap of any non-standard game mode.
"""
struct OtherBeatmap <: Beatmap
    id::Int  # Beatmap ID.
    set_id::Int  # Beatmapset ID.
    artist::AbstractString  # Song artist.
    title::AbstractString  # Song title.
    diff::AbstractString  # Diff name.
    mapper::AbstractString  # Mapper name.
    stars::Float16  # Star rating.
    cs::Float16  # Circle size.
    od::Float16  # Overall difficulty.
    ar::Float16  # Approach rate.
    hp::Float16  # HP drain.
    bpm::Float16  # Song BPM.
    length::Dates.Second  # Song length.
    status::Status  # Ranked status.
    approved_date::DateTime  # Date and time ranked/loved/qualified.
    last_update::DateTime  # Date and time last updated.
    plays::Int  # Play count.

    function OtherBeatmap(d::Dict)
        fmt = DateFormat("y-m-d H:M:S")
        new(
            parse(Int, d["beatmap_id"]),
            parse(Int, d["beatmapset_id"]),
            d["artist"],
            d["title"],
            d["version"],
            d["creator"],
            parse(Float16, d["difficultyrating"]),
            parse(Float16, d["diff_size"]),
            parse(Float16, d["diff_overall"]),
            parse(Float16, d["diff_approach"]),
            parse(Float16, d["diff_drain"]),
            parse(Float16, d["bpm"]),
            Dates.Second(d["total_length"]),
            Status[parse(Int, d["approved"])][1],
            DateTime(d["approved_date"], fmt),
            DateTime(d["last_update"], fmt),
            parse(Int, d["playcount"]),
        )
    end
end

"""
    make_map(view::Dict) -> Beatmap

Get a beatmap of the appropriate type from `view`.
"""
function make_map(view::Dict)
    mode = parse(Int, view["mode"])
    return if mode == Int(STD)
        StdBeatmap(view)
    else
        OtherBeatmap(view)
    end
end

"""
A recent accomplishment by a player displayed on their profile. We use it to find map IDs.
"""
struct Event
    map_str::AbstractString  # Artist - Title [Diff].
    map_id::Int  # Beatmap ID.
    mapset_id::Int  # Mapset ID.

    function Event(d::Dict)
        regex = r"/b/[0-9]+\?m=[0-9]'>(.+) - (.+) \[(.+)\]</a>"
        caps = match(regex, d["display_html"]).captures
        return if length(caps) == 3
            map_str = "$(caps[1]) - $(caps[2]) [$(caps[3])]"
            new(map_str, parse(Int, d["beatmap_id"]), parse(Int, d["beatmapset_id"]))
        else
            new("", parse(Int, d["beatmap_id"]), parse(Int, d["beatmapset_id"]))
        end
    end
end

"""
An osu! player.
"""
struct Player
    id::Int  # User ID.
    name::AbstractString  # Username.
    pp::Int  # Raw pp.
    rank::Int  # Overall rank.
    accuracy::Float32  # Overall accuracy.
    playcount::Int  # Ranked playcount.
    events::Vector{Event}  # Recent events.

    function Player(d::Dict)
        new(
            parse(Int, d["user_id"]),
            d["username"],
            round(parse(Float32, d["pp_raw"])),
            parse(Int, d["pp_rank"]),
            parse(Float16, d["accuracy"]),
            parse(Int, d["playcount"]),
            map(e -> Event(e), d["events"]),
        )
    end
end

"""
A player's score on a map.
"""
struct Score
    map_id::Int  # Beatmap ID.
    user_id::Nullable{Int}  # Player ID (not always supplied).
    username::Nullable{AbstractString}  # Player usernamew (not always supplied).
    date::DateTime  # Date of the play.
    mods::Int  # Mods on the play.
    fc::Bool  # Whether or not the play is a full combo.
    accuracy::Float32  # Accuracy of the play, in percent.
    pp::Nullable{Int}  # pp for the play (not always supplied).
    combo::Int  # Max combo on the play.

    function Score(d::Dict)
        new(
            parse(Int, d["beatmap_id"]),
            Nullable{Int}(haskey(d, "user_id") ? parse(Int, d["user_id"]) : nothing),
            Nullable{AbstractString}(haskey(d, "username") ? d["username"] : nothing),
            DateTime(d["date"], fmt),
            parse(Int, d["enabled_mods"]),
            d["perfect"] == "1",
            accuracy(
                parse(Int, d["count300"]),
                parse(Int, d["count100"]),
                parse(Int, d["count50"]),
                parse(Int, d["countgeki"]),
                parse(Int, d["countkatu"]),
                parse(Int, d["countmiss"]);
                mode=d["mode"],
            ),
            Nullable{Int}(haskey(d, "pp") ? round(parse(Float32, d["pp"])) : nothing),
            parse(Int, d["maxcombo"]),
        )
    end
end

"""
    accuracy(
        count300::Int,
        count100::Int,
        count50::Int,
        countgeki::Int,
        countkatu::Int,
        misses::Int;
        mode::Mode=OsuTypes.STD,
    ) -> Float64

Get a play's accuracy in percent.
"""
function accuracy(
    count300::Int,
    count100::Int,
    count50::Int,
    countgeki::Int,
    countkatu::Int,
    misses::Int;
    mode::Mode=OsuTypes.STD,
)
    # https://osu.ppy.sh/help/wiki/Accuracy/
    return 100 * if mode == OsuTypes.STD
        /(
            count300 + count100/3 + count50/6,
            count300 + count100 + count50 + misses,
        )
    elseif mode == TAIKO
        (count300 + count100/2) / (count300 + count100 + misses)
    elseif mode == CTB
        /(
            count300 + count100 + count50,
            count300 + count100 + count50 + countkatu + misses,
        )
    elseif mode == MANIA
        /(
            countgeki + count300 + 2countkatu/3 + count100/3 + count50/6,
            countgeki + count300 + countkatu + count100 + count50 + misses,
        )
    end
end

log(msg) = info("$(basename(@__FILE__)): $msg")

end

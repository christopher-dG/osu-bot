"""
Types that represent concepts/objects in osu!.
"""
module OsuTypes

using HTTP
using JSON

export mod_map, make_map, Beatmap, StdBeatmap, TaikoBeatmap, OtherBeatmap, User, Score,
    Mode

const fmt = DateFormat("y-m-d H:M:S")
const osu = "https://osu.ppy.sh"
const osu_key = ENV["OSU_API_KEY"]
const id_regex = r"Creator:</td><td class=[\"']colour[\"']><a href=[\"']/u/(\d+)"
const event_regex = r"/b/[0-9]+\?m=[0-9]'>(.+ - .+ \[.+\])</a> \((.*)\)"

@enum Mode STD TAIKO CTB MANIA

const status_map = Dict{Int, String}(
    -2 => "Unranked",
    -1 => "Unranked",
    0 => "Unranked",
    1 => "Ranked",
    2 => "Ranked",
    3 => "Qualified",
    4 => "Loved",
)

# https://github.com/ppy/osu-api/wiki#mods
const mod_map = Dict{Symbol, Int}(
    :NOMOD => 1 >> 1,
    :NF => 1 << 0,
    :EZ => 1 << 1,
    :NV => 1 << 2,  # "NoVideo" mod sometimes present on really old plays.
    :HD => 1 << 3,
    :HR => 1 << 4,
    :SD => 1 << 5,
    :DT => 1 << 6,
    :RL => 1 << 7,
    :HT => 1 << 8,
    :NC => 1 << 6 | 1 << 9,  # DT is always set along with NC.
    :FL => 1 << 10,
    :AT => 1 << 11,
    :SO => 1 << 12,
    :AP => 1 << 13,
    :PF => 1 << 5 | 1 << 14,  # SD is always set along with PF.
    :FREEMOD => -1,
)

"""
    A beatmap of any mode.
"""
abstract type Beatmap end

"""
    StdBeatmap(d::Dict) -> StdBeatmap

Create an osu!std beatmap from `d`.
Note: Autoconverts are also of this type.
"""
struct StdBeatmap <: Beatmap
    id::Int  # Beatmap ID.
    set_id::Int  # Beatmapset ID.
    artist::AbstractString  # Song artist.
    title::AbstractString  # Song title.
    diff::AbstractString  # Diff name.
    mapper::AbstractString  # Mapper name.
    mapper_id::Nullable{Int}  # Mapper id.
    stars::AbstractFloat  # Star rating.
    cs::AbstractFloat  # Circle size.
    od::AbstractFloat  # Overall difficulty.
    ar::AbstractFloat  # Approach rate.
    hp::AbstractFloat  # HP drain.
    bpm::AbstractFloat  # Song BPM.
    length::Dates.Second  # Song length.
    status::AbstractString  # Ranked status.
    approved_date::Nullable{Date}  # Date ranked/loved/qualified.
    plays::Int  # Play count.
    combo::Int  # Max combo.
    mode::Mode  # Game mode.

    function StdBeatmap(d::Dict)
        status_key = haskey(d, "approved") ? "approved" : "beatmap_status"
        status = get(status_map, parse(Int, d[status_key]), "Unknown")
        date_key = haskey(d, "approved_date") ? "approved_date" : "date"
        approved_date = try Date(replace(d[date_key], "T", " "), fmt) catch end
        # The following is to correct the mapper name in case of name changes.
        # id is mapper id not player id, name is mapper name not player name.
        id = mapper_id(d["beatmap_id"])
        name = if isnull(id)
            get(d, "creator", get(d, "mapper", ""))
        else
            get(mapper_name(get(id)), get(d, "creator", get(d, "mapper", "")))
        end
        new(
            parse(Int, d["beatmap_id"]),
            parse(Int, d["beatmapset_id"]),
            d["artist"],
            d["title"],
            get(d, "version", get(d, "difficulty_name", "")),
            name,
            id,
            parse(Float64, get(d, "difficultyrating", get(d, "difficulty", ""))),
            parse(Float64, get(d, "diff_size", get(d, "difficulty_cs", ""))),
            parse(Float64, get(d, "diff_overall", get(d, "difficulty_od", ""))),
            parse(Float64, get(d, "diff_approach", get(d, "difficulty_ar", ""))),
            parse(Float64, get(d, "diff_drain", get(d, "difficulty_hp", ""))),
            parse(Float64, d["bpm"]),
            Dates.Second(d["total_length"]),
            status,
            approved_date,
            parse(Int, get(d, "playcount", get(d, "play_count", "0"))),
            # Autoconverts from std to taiko have null max combo.
            try parse(Int, get(d, "max_combo", "-1")) catch -1 end,
            STD,
        )
    end
end

"""
    TaikoBeatmap(d::Dict) -> TaikoBeatmap

Create an osu!taiko beatmap from `d`.
"""
struct TaikoBeatmap <: Beatmap
    id::Int  # Beatmap ID.
    set_id::Int  # Beatmapset ID.
    artist::AbstractString  # Song artist.
    title::AbstractString  # Song title.
    diff::AbstractString  # Diff name.
    mapper::AbstractString  # Mapper name.
    mapper_id::Nullable{Int}  # Mapper id.
    stars::AbstractFloat  # Star rating.
    cs::AbstractFloat  # Circle size.
    od::AbstractFloat  # Overall difficulty.
    ar::AbstractFloat  # Approach rate.
    hp::AbstractFloat  # HP drain.
    bpm::AbstractFloat  # Song BPM.
    length::Dates.Second  # Song length.
    status::AbstractString  # Ranked status.
    approved_date::Nullable{Date}  # Date ranked/loved/qualified.
    plays::Int  # Play count.
    mode::Mode  # Game mode.

    function TaikoBeatmap(d::Dict)
        status_key = haskey(d, "approved") ? "approved" : "beatmap_status"
        status = get(status_map, parse(Int, d[status_key]), "Unknown")
        date_key = haskey(d, "approved_date") ? "approved_date" : "date"
        approved_date = try Date(replace(d[date_key], "T", " "), fmt) catch end
        # The following is to correct the mapper name in case of name changes.
        # id is mapper id not player id, name is mapper name not player name.
        id = mapper_id(d["beatmap_id"])
        name = if isnull(id)
            get(d, "creator", get(d, "mapper", ""))
        else
            get(mapper_name(get(id)), get(d, "creator", get(d, "mapper", "")))
        end
        new(
            parse(Int, d["beatmap_id"]),
            parse(Int, d["beatmapset_id"]),
            d["artist"],
            d["title"],
            get(d, "version", get(d, "difficulty_name", "")),
            name,
            id,
            parse(Float64, get(d, "difficultyrating", get(d, "difficulty", ""))),
            parse(Float64, get(d, "diff_size", get(d, "difficulty_cs", ""))),
            parse(Float64, get(d, "diff_overall", get(d, "difficulty_od", ""))),
            parse(Float64, get(d, "diff_approach", get(d, "difficulty_ar", ""))),
            parse(Float64, get(d, "diff_drain", get(d, "difficulty_hp", ""))),
            parse(Float64, d["bpm"]),
            Dates.Second(d["total_length"]),
            status,
            approved_date,
            parse(Int, get(d, "playcount", get(d, "play_count", "0"))),
            TAIKO,
    )
    end
end

"""
    OtherBeatmap(d::Dict) -> OtherBeatmap

Create an osu!ctb or osu!mania beatmap from `d` (incompatible with oppai).
"""
struct OtherBeatmap <: Beatmap
    id::Int  # Beatmap ID.
    set_id::Int  # Beatmapset ID.
    artist::AbstractString  # Song artist.
    title::AbstractString  # Song title.
    diff::AbstractString  # Diff name.
    mapper::AbstractString  # Mapper name.
    mapper_id::Nullable{Int}
    stars::AbstractFloat  # Star rating.
    cs::AbstractFloat  # Circle size.
    od::AbstractFloat  # Overall difficulty.
    ar::AbstractFloat  # Approach rate.
    hp::AbstractFloat  # HP drain.
    bpm::AbstractFloat  # Song BPM.
    length::Dates.Second  # Song length.
    status::AbstractString  # Ranked status.
    approved_date::Nullable{Date}  # Date ranked/loved/qualified.
    plays::Int  # Play count.
    mode::Mode  # Game mode.

    function OtherBeatmap(d::Dict)
        status_key = haskey(d, "approved") ? "approved" : "beatmap_status"
        status = get(status_map, parse(Int, d[status_key]), "Unknown")
        date_key = haskey(d, "approved_date") ? "approved_date" : "date"
        approved_date = try Date(replace(d[date_key], "T", " "), fmt) catch end
        # The following is to correct the mapper name in case of name changes.
        # id is mapper id not player id, name is mapper name not player name.
        id = mapper_id(d["beatmap_id"])
        name = if isnull(id)
            get(d, "creator", get(d, "mapper", ""))
        else
            get(mapper_name(get(id)), get(d, "creator", get(d, "mapper", "")))
        end
        new(
            parse(Int, d["beatmap_id"]),
            parse(Int, d["beatmapset_id"]),
            d["artist"],
            d["title"],
            get(d, "version", get(d, "difficulty_name", "")),
            name,
            id,
            parse(Float64, get(d, "difficultyrating", get(d, "difficulty", ""))),
            parse(Float64, get(d, "diff_size", get(d, "difficulty_cs", ""))),
            parse(Float64, get(d, "diff_overall", get(d, "difficulty_od", ""))),
            parse(Float64, get(d, "diff_approach", get(d, "difficulty_ar", ""))),
            parse(Float64, get(d, "diff_drain", get(d, "difficulty_hp", ""))),
            parse(Float64, d["bpm"]),
            Dates.Second(d["total_length"]),
            status,
            approved_date,
            parse(Int, get(d, "playcount", get(d, "play_count", "0"))),
            first(Mode[parse(Int, d["mode"])]),
        )
    end
end

"""
    make_map(view::Dict) -> Beatmap

Get a beatmap of the appropriate type from `view`.
"""
function make_map(view::Dict)
    mode = parse(Int, get(view, "mode", get(view, "gamemode", "-1")))
    mode == -1 && error()
    return if mode == Int(STD)
        StdBeatmap(view)
    elseif mode == Int(TAIKO)
        TaikoBeatmap(view)
    else
        OtherBeatmap(view)
    end
end

"""
    Event(d::Dict) -> Event

Create an accomplishment by a player displayed on their profile, used to find map IDs from
`d`.
"""
struct Event
    map_str::AbstractString  # Artist - Title [Diff].
    map_id::Int  # Beatmap ID.
    mapset_id::Int  # Mapset ID.
    mode::Nullable{Mode}

    function Event(d::Dict)
        try
            caps = match(event_regex, d["display_html"]).captures
            caps = replace.(caps, "&quot;", "\"")
            mode = uppercase(caps[2])
            mode = if mode == "OSU!"
                STD
            elseif mode == "TAIKO"
                TAIKO
            elseif mode == "CATCH THE BEAT"
                CTB
            elseif mode == "OSU!MANIA"
                MANIA
            end
            new(caps[1], parse(Int, d["beatmap_id"]), parse(Int, d["beatmapset_id"]), mode)
        catch
            new("", parse(Int, d["beatmap_id"]), parse(Int, d["beatmapset_id"]), nothing)
        end
    end
end

"""
    User(d::Dict) -> User

Create an osu! player from `d`.
"""
struct User
    id::Int  # User ID.
    name::AbstractString  # Username.
    pp::Int  # Raw pp.
    rank::Int  # Overall rank.
    accuracy::AbstractFloat  # Overall accuracy.
    playcount::Int  # Ranked playcount.
    events::Vector{Event}  # Recent events.

    function User(d::Dict)
        new(
            parse(Int, d["user_id"]),
            d["username"],
            round(parse(Float64, d["pp_raw"])),
            parse(Int, d["pp_rank"]),
            parse(Float64, d["accuracy"]),
            parse(Int, d["playcount"]),
            map(e -> Event(e), d["events"]),
        )
    end
end

"""
    Score(d::Dict) -> Score

Create a player's score on a map from `d`.
"""
struct Score
    map_id::Int  # Beatmap ID.
    user_id::Nullable{Int}  # User ID (not always supplied).
    username::Nullable{AbstractString}  # User username (not always supplied).
    date::DateTime  # Date of the play.
    mods::Int  # Mods on the play.
    fc::Bool  # Whether or not the play is a full combo.
    accuracy::AbstractFloat  # Accuracy of the play, in percent.
    pp::Nullable{Int}  # pp for the play (not always supplied).
    combo::Int  # Max combo on the play.
    misses::Int  # Number of misses on the play.

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
            Nullable{Int}(haskey(d, "pp") ? round(parse(Float64, d["pp"])) : nothing),
            parse(Int, d["maxcombo"]),
            parse(Int, d["countmiss"]),
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
        mode::Mode=STD,
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
    mode::Mode=STD,
)
    # https://osu.ppy.sh/help/wiki/Accuracy/
    return 100 * if mode == STD
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

"""
    mapper_id(map_id::Union{Int, AbstractString}) -> Nullable{Int}

Try to get the user id of a map's mapper. Probably belongs more in OsuBot.Osu but creates
some circular imports.
"""
function mapper_id(map_id::Union{Int, AbstractString})
    url = "$osu/b/$map_id"
    log("Making request to $url")
    r = try
        HTTP.get(url)
    catch e
        log(e)
        return Nullable{Int}()
    end
    body = String(take!(r))
    m = match(id_regex, body)
    return if m == nothing
        log("No match found for mapper id")
        Nullable{Int}()
    else
        id = m.captures[1]
        log("Found match: $id")
        Nullable{Int}(parse(Int, id))
    end
end

"""
    mapper_name(mapper_id::Int) -> Nullable{String}

Get a mapper's name from their id, which deals with name changes. This should also be
in OsuBot.Osu.
"""
function mapper_name(mapper_id::Int)
    url = "$osu/api/get_user?k=$osu_key&u=$mapper_id&type=id&event_days=0"
    log("Making request to $(replace(url, osu_key, "[secure]"))")
    return try
        return Nullable(first(JSON.parse(String(take!(HTTP.get(url)))))["username"])
    catch e
        log(e)
        return Nullable{String}()
    end
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

using Formatting
using OsuBot

import Base: search, log

if abspath(PROGRAM_FILE) == @__FILE__
    const osu = "https://osu.ppy.sh"
    const dry = in("DRY", ARGS) || in("TEST", ARGS)
    const title_regex = r"(.+)\|(.+)-(.+)\[(.+)\].*"
    Reddit.login()
    stream = Reddit.posts()
    for post in stream
        try
            !dry && post[:saved] && log("'$(post[:title])' is already saved") && continue
            post[:is_self] && log("'$(post[:title])' is a self post") && continue
            m = match(title_regex, post[:title])
            m == nothing && log("'$(post[:title])' is not a score post") && continue
            caps = strip.(m.captures)
            player = Osu.player(caps[1])
            !player.hasvalue && log("No player found for $(caps[1])") && continue
            map_str = "$(caps[2]) - $(caps[3]) [$(caps[4])]"
            map = Nullable{OsuTypes.Beatmap}(search(get(player), map_str))
            comment_str = build_comment(get(player), map)
            log("Commenting on $(post[:title]): $comment_str (dry=$dry)")
            !dry && Reddit.reply_sticky(post, comment_str)
        catch e
            log(e)
        end
    end
end

"""
    search(player::Osu.Player, map_str::AbstractString) -> Nullable{OsuTypes.Beatmap}

Search `player`'s recent events and plays for a map called `map_str`.
"""
function search(player::Osu.Player, map_str::AbstractString)
    log("Searching $(length(player.events)) recent events")
    map = try
        Osu.beatmap(
            player.events[first(find(e -> e.map_str == map_str, player.events))].map_id,
        )
    catch e
        log(e)
        Nullable()
    end
    map.hasvalue && log("Found map: $(OsuTypes.map_str(get(map)))") && return map

    log("Searching recent plays")
    recent = get(Osu.player_recent(player.id; lim=50), [])
    for map in (Osu.beatmap(play.map_id) for play in recent)
        !map.hasvalue && continue
        OsuTypes.map_str(get(map)) == map_str && return map
    end
    log("No map found") && return nothing
end

"""
    build_comment(player::OsuTypes.Player, beatmap::OsuTypes.Beatmap) -> String

Build a comment from `player` and `beatmap`.
"""
function build_comment(player::OsuTypes.Player, beatmap::Nullable{OsuTypes.Beatmap})
    const osu = "https://osu.ppy.sh"
    buf = IOBuffer()
    tmp = ""
    if beatmap.hasvalue
        map = get(beatmap)
        tmp = "[$(OsuTypes.map_str(map))]($osu/b/$(map.id)) [(↓)]($osu/d/$(map.id)) "
        tmp *= "by [$(map.mapper)]($osu/u/$(map.mapper))"
        Markdown.plain(buf, Markdown.Header(tmp, 3))
        tmp = ""
        plays = Osu.beatmap_scores(map.id)
        if !plays.hasvalue
            top = get(plays)[1]
            # Output from `beatmap_scores` always has both `username` and `usr_id` fields,
            # so we shouldn't need to handle `NullException`s.
            tmp = "#1: [$(get(top.username))]($osu/u/$(get(top.user_id))) ("
            if top.mods != OsuTypes.mod_map[:NOMOD]
                tmp *= "+$(join(mods_from_int(top.mods))) - "
            end
            # `beatmap_scores` also always comes with `pp` set.
            tmp *= "$(trunc(top.accuracy, 2))% - "
            tmp *= "$(format(get(top.pp); commas=true))pp) || "
        end
        if isa(map, OsuTypes.StdBeatmap)
            tmp *= "$(format(map.combo; commas=true))x max combo || "
        end
        tmp *= "$(map.status) ($(map.approved_date)) || "
        tmp *= "$(format(map.plays; commas=true)) plays"
        Markdown.plaininline(buf, Markdown.Bold(tmp))
        tmp = ""
    end
    return String(take!(buf))
end

"""
    mods_from_string(s::AbstractString) -> Int

Get a number representation of the mods in `s`. This does not deal with the odd case of
mods separated by spaces.
"""
function mods_from_string(s::AbstractString)
    mods = 0
    s = uppercase(s[search(s, "]").stop + 1:end])
    idx = search(s, "+").stop + 1

    # The "easy case" is when there's a '+' before the mods.
    if idx != 0 && idx < length(s)
        s = s[idx:end]
        s = replace(split(s[findfirst(!isspace, s):end])[1], r"[^A-Z]", "")
        s = length(s) == 0 ? s : s[1:end-1]
        for idx in 1:2:length(s)
            mod = Symbol(s[idx:idx + 1])
            mods += get(OsuTypes.mod_map, mod, 0)
        end
        return mods

    # This case is a lot more iffy.
    else
        for token in split(s)
            token = replace(token, r"[^A-Z]", "")
            length(token) % 2 != 0 && continue
            println(token)
            for idx in 1:2:length(token)
                mod = Symbol(token[idx:idx + 1])
                mods += get(OsuTypes.mod_map, mod, 0)
            end
            mods > 0 && return mods
        end
    end
    return mods
end

"""
    mods_from_int(n::Int) -> Vector{Symbol}

Get a list of mods from `n`.
"""
function mods_from_int(n::Int)
    const order = [:EZ, :HD, :HT, :DT, :NC, :HR, :FL, :NF, :SD, :PF, :RL, :SO, :AP, :AT]
    mods = Symbol[]
    for (k, v) in reverse(sort(collect(OsuTypes.mod_map); by=p -> p.second))
        if v <= n
            push!(mods, k)
            n -= v
            n <= 0 && return filter(m -> in(m, mods), order)
        end
    end
end

function map_title(buf::IO, beatmap::OsuTypes.Beatmap)
    tmp = "[$(OsuTypes.map_str(map))]($osu/b/$(map.id)) [(↓)]($osu/d/$(map.id))"
    tmp *= "by [$(map.mapper)]($osu/u/$(map.mapper))"
    Markdown.plain(buf, Markdown.header(tmp, 3))
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

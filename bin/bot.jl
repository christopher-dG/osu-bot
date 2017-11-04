#!/usr/bin/env julia

using OsuBot

import Base.log
import OsuBot.log

args = uppercase.(ARGS)
const do_posts = !in("NOPOSTS", args)
const do_mentions = !in("NOCOMMENTS", args)
const dry = in("DRY", args)
const title_regex = r"(.+)\|(.+ - .+\[.+\]).*"
const acc_regex = r"(\d+(?:[,.]\d*)?)%"

function abbrev(comment::AbstractString)
    short = length(comment) > 80 ? "$(comment[1:80])..." : comment
    return replace(short, "\n", "\\n")
end

function has_reply(comment)
    try
        comment[:refresh]()  # Required to fill the replies vector.
    catch e
        # https://github.com/praw-dev/praw/issues/838#issuecomment-325230667
        log("$e\nRefreshing comment failed, trying a second time")
        sleep(10)
        try
            comment[:refresh]()
            log("Second attempt succeeded")
        catch e
            log("Second attempt failed, assuming there is a reply: $e")
            return true
        end
    end
    return any(r -> r[:author][:name] == name, comment[:replies])
end

"""
    from_title(title::AbstractString) -> String

Generate a comment string from a post title. Errors on failure.
"""
function from_title(title::AbstractString)
    caps = strip.(match(title_regex, title).captures)
    player_name = Utils.parse_player(caps[1])
    player = Osu.user(player_name)
    isnull(player) && warn("Player $player_name not found")
    beatmap, mode = Utils.search(player, caps[2])
    isnull(beatmap) && warn("Beatmap was not found")
    isnull(player) && isnull(beatmap) && error("Neither player nor map could be found")
    mods = Utils.mods_from_string(title)
    title_end = strip(title[search(title, caps[2]).stop + 2:end])
    acc = match(acc_regex, title_end)
    acc = if acc == nothing
        Nullable{Real}()
    else
        acc = min(parse(Float64, replace(acc.captures[1], ",", ".")), 100.0)
        log("Found accuracy in title: $acc%")
        Nullable(acc)
    end
    return CommentMarkdown.build_comment(player, beatmap, mods, acc, mode)
end

"""
    player_reply(line::AbstractString) -> String

Generate a player table for a !player command.
"""
function player_reply(line::AbstractString)
    # TODO: Parse a game mode, probably as :MODE at the end of the line.
    token = split(line, " "; limit=2)[end]  # Get rid of "!player".
    (all(isspace, token) || token == "!player") && error("Command is not well-formed: $line")
    log("Getting player from username: $token")
    player = Osu.user(token)
    if !isnull(player)
        buf = IOBuffer()
        try
            CommentMarkdown.player_table!(buf, get(player), OsuTypes.STD)
            reply = strip(String(take!(buf)))
            log("Generated a player table for: $line")
            return reply
        catch e
            error("Generating a player table failed: $e")
        end
    else
        error("Couldn't get player from $token")
    end
end

"""
    map_reply(line::AbstractString) -> String

Generate map info for a !map command.
"""
function map_reply(line::AbstractString)
    tokens = split(line)[2:end]  # Get rid of "!map".
    isempty(tokens) && error("Command is not well-formed: $line")
    map_id = first(tokens)
    mods, acc = if length(tokens) > 1
        args = join(tokens[2:end], " ")

        log("Getting mods and acc from $args")
        mods = Utils.mods_from_string(args)
        acc = match(acc_regex, args)
        acc = if acc == nothing
            log("Didn't find acc in comment")
            100
        else
            log("Found acc in comment")
            min(parse(Float64, replace(acc.captures[1], ",", ".")), 100)
        end
        log("acc=$acc%, mods=$mods")
        mods, acc
    else
        log("Didn't find any extra arguments")
        0, 100
    end

    id = try
        parse(Int, map_id)
    catch e
        error("Couldn't parse a map id from $map_id: $e")
    end

    beatmap = Osu.beatmap(id)
    if !isnull(beatmap)
        buf = IOBuffer()
        try
            beatmap = get(beatmap)
            CommentMarkdown.map_basics!(buf, beatmap, beatmap.mode)
            write(buf, "\n")
            CommentMarkdown.map_table!(buf, beatmap, acc, mods, beatmap.mode)
            reply = strip(String(take!(buf)))
            log("Genererated a map table for: $line")
            return reply
        catch e
            error("Generating map info failed: $e")
        end
    else
        error("Couldn't get beatmap from $(join(tokens, " "))")
    end
end

"""
    leaderboard_reply(line::AbstractString) -> String

Generate the map leaderboard for a !leaderboard command.
"""
function leaderboard_reply(line::AbstractString)
    tokens = split(line)[2:end]  # Get rid of "!leaderboard".
    id = try
        parse(Int, first(tokens))
    catch e
        error("Couldn't parse a map id from $(first(tokens)): $e")
    end
    beatmap = Osu.beatmap(id)
    if isnull(beatmap)
        error("Couldn't get a beatmap from $id")
    end

    n, mods = 5, OsuTypes.mod_map[:FREEMOD]
    if length(tokens) > 1
        log("Getting n and mods from $(join(tokens, " "))")
        for token in tokens[2:end]  # Number of scores to show.
            if all(isdigit, token) && token != "0"
                n = min(parse(Int, token), 10)  # Don't show more than 10.
            else  # Try to parse mods.
                maybe_mods = Utils.mods_from_string(token)
                if maybe_mods != 0
                    mods = maybe_mods
                end
            end
        end
    else
        log("Command does not contain any extra tokens")
    end

    buf = IOBuffer()
    CommentMarkdown.map_basics!(buf, get(beatmap), OsuTypes.STD; minimal=true)
    write(buf, "\n")
    try
        log("Getting leaderboard for map $id")
        CommentMarkdown.leaderboard!(buf, get(beatmap); mods=mods, n=n)
    catch e
        error("Couln't generate leaderboard: $e")
    end
    reply = strip(String(take!(buf)))
end

if abspath(PROGRAM_FILE) == @__FILE__
    log("Running with args: do_posts=$(do_posts), do_mentions=$(do_mentions), dry=$(dry)")
    Reddit.login()

    if do_posts
        posts_chan = Channel(1)
        @async Reddit.posts(posts_chan)
        @async while true
            post = take!(posts_chan)
            try
                !dry && post[:saved] && log("'$(post[:title])' is already saved") && continue
                post[:is_self] && log("'$(post[:title])' is a self post") && continue
                m = match(title_regex, post[:title])
                m == nothing && log("'$(post[:title])' is not a score post") && continue
                title = post[:title]
                log("Found a score post: $title")
                try
                    comment_str = from_title(title)
                    log("Commenting on $(post[:title]): \n$comment_str")
                    !dry && Reddit.reply(post, comment_str; sticky=true)
                catch e
                    log("Comment generation/transmission failed: $e")
                end
            catch e
                log(e)
            end
        end
    end

    if do_mentions
        name = Reddit.bot[:user][:me]()[:name]
        mention = Regex("/?u/$name")
        mentions_chan = Channel(1)
        @async Reddit.mentions(mentions_chan)
        @async while true
            comment = take!(mentions_chan)
            short = abbrev(comment[:body])
            !dry && has_reply(comment) && log("'$short' already has a reply") && continue
            body = strip(replace(comment[:body], mention, ""))

            log("Found a comment: $short")
            reply = ""
            for line in strip.(split(body, "\n"))
                if startswith(line, "!player")
                    try reply *= "$(player_reply(line))\n\n" catch e log(e) end
                elseif startswith(line, "!map")
                    try reply *= "$(map_reply(line))\n\n" catch e log(e) end
                elseif startswith(line, "!leaderboard")
                    try reply *= "$(leaderboard_reply(line))\n\n" catch e log(e) end
                end
            end
            if !all(isspace, reply)  # Make sure that at least one command worked.
                reply *= CommentMarkdown.footer()
                log("Replying to '$short':\n$reply")
                !dry && Reddit.reply(comment, reply)
                !dry && comment[:mark_read]()
            else
                log("Ignoring: $short")
            end
        end
    end

    while true sleep(1) end
end

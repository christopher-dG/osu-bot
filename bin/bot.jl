#!/usr/bin/env julia
using OsuBot

import Base.log

const title_regex = r"(.+)\|(.+ - .+\[.+\]).*"
const acc_regex = r"(\d+(?:[,.]\d*)?)%"
const osu = "https://osu.ppy.sh"
const dry = in("DRY", ARGS) || in("TEST", ARGS)

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

abbrev(comment::AbstractString) = length(comment) > 80 ? "$(comment[1:80])..." : comment

"""
    from_title(title::AbstractString) -> String

Generate a comment string from a post title. Errors on failure.
"""
function from_title(title::AbstractString)
    caps = strip.(match(title_regex, title).captures)
    player = Osu.user(Utils.parse_player(caps[1]))
    isnull(player) && error("Player $(caps[1]) not found")
    beatmap, mode = Utils.search(get(player), caps[2])
    isnull(beatmap) && warn("Beatmap was not found")
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
    return CommentMarkdown.build_comment(get(player), beatmap, mods, acc, mode)
end

"""
    player_reply(comment) -> Void

Reply to a comment with a player table generated from `comment`'s body.
`comment` is a PyObject.
"""
function player_reply(comment)
    token = split(comment[:body], " "; limit=2)[end]
    player = if startswith(token, ":")
        log("Getting player from id: $(token[2:end])")
        id = try
            parse(Int, token[2:end])
        catch e
            log("Couldn't parse a player id from $(token[2:end]): $e")
            return
        end
        Osu.user(id)
    else
        log("Getting player from username: $token")
        Osu.user(token)
    end
    if !isnull(player)
        buf = IOBuffer()
        try
            # TODO: Parse a game mode.
            CommentMarkdown.player_table!(buf, get(player), OsuTypes.STD)
            CommentMarkdown.footer!(buf)
            reply_str = String(take!(buf))
            log("Replying to $(abbrev(comment[:body])):\n$(reply_str)")
            !dry && Reddit.reply(comment, reply_str)
        catch e
            log("Comment generation/transmission failed: $e")
        end
    else
        log("Couldn't get player from $token")
    end
    return
end

function map_reply(comment)
    tokens = split(comment[:body])[2:end]
    idx = search(tokens[end], "+").stop
    # mods_from_string expects a post title containng a ']'.
    mods = idx == -1 ? 0 : Utils.mods_from_string("]$(tokens[end][idx:end])")
    log("Found mods: $mods")
    id = try
        parse(Int, tokens[1])
    catch e
        log("Couldn't parse a map id from $(join(tokens, " ")): $e")
        return
    end
    beatmap = Osu.beatmap(id)
    if !isnull(beatmap)
        buf = IOBuffer()
        try
            beatmap = get(beatmap)
            CommentMarkdown.map_basics!(buf, beatmap, beatmap.mode)
            write(buf, "\n\n")
            CommentMarkdown.map_table!(buf, beatmap, 100, mods, beatmap.mode)
            CommentMarkdown.footer!(buf)
            reply_str = String(take!(buf))
            log("Replying to $(abbrev(comment[:body])):\n$(reply_str)")
            !dry && Reddit.reply(comment, reply_str)
        catch e
            log("Comment generation/transmission failed: $e")
        end
    else
        log("Couldn't get beatmap from $(join(tokens, " "))")
    end
    return
end

function score_reply(comment)
end

if abspath(PROGRAM_FILE) == @__FILE__
    log("Running with dry=$(dry)")
    Reddit.login()
    posts_chan = Channel(1)
    @async Reddit.posts(posts_chan)
    # @async while true
    #     post = take!(posts_chan)
    #     try
    #         !dry && post[:saved] && log("'$(post[:title])' is already saved") && continue
    #         post[:is_self] && log("'$(post[:title])' is a self post") && continue
    #         m = match(title_regex, post[:title])
    #         m == nothing && log("'$(post[:title])' is not a score post") && continue
    #         title = post[:title]
    #         log("Found a score post: $title")
    #         try
    #             comment_str = from_title(title)
    #             log("Commenting on $(post[:title]): \n$comment_str")
    #             !dry && Reddit.reply(post, comment_str; sticky=true)
    #         catch e
    #             log("Comment generation/transmission failed: $e")
    #         end
    #     catch e
    #         log(e)
    #     end
    # end

    comments_chan = Channel(1)
    @async Reddit.comments(comments_chan)
    @async while true
        comment = take!(comments_chan)
        short = abbrev(comment[:body])
        !dry && comment[:saved] && log("'$short' is already saved") && continue
        if startswith(comment[:body], "!player")
            player_reply(comment)
        elseif startswith(comment[:body], "!map")
            map_reply(comment)
        elseif startswith(comment[:body], "!score")
            score_reply(comment)
        else
            log("Ignoring comment: $short")
        end
    end

    while true sleep(1) end
end

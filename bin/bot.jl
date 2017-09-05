#!/usr/bin/env julia
using OsuBot

import Base.log

const title_regex = r"(.+)\|(.+)-(.+)\[(.+)\].*"
const osu = "https://osu.ppy.sh"
const dry = in("DRY", ARGS) || in("TEST", ARGS)

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

"""
    from_title(title::AbstractString) -> String

Generate a comment string from a post title. Errors on failure.
"""
function from_title(title::AbstractString)
    caps = strip.(match(title_regex, title).captures)
    player = Osu.user(Utils.parse_player(caps[1]))
    isnull(player) && error("Player $(caps[1]) not found")
    map_str = "$(caps[2]) - $(caps[3]) [$(caps[4])]"
    beatmap, mode = Utils.search(get(player), map_str)
    isnull(beatmap) && warn("Beatmap was not found")
    mods = Utils.mods_from_string(title)
    title_end = strip(title[search(title, caps[4]).stop + 2:end])
    acc = match(r"(\d{1,2}\.?\d{1,2})%", title_end)
    acc = if acc == nothing
        Nullable{Real}()
    else
        log("Found accuracy in title: $(acc.captures[1])")
        Nullable(parse(Float64, acc.captures[1]))
    end
    return CommentMarkdown.build_comment(get(player), beatmap, mods, acc, mode)
end

if abspath(PROGRAM_FILE) == @__FILE__
    log("Running with dry=$(dry)")
    Reddit.login()
    channel = Channel(1)
    @async Reddit.posts(channel)
    @async while true
        post = take!(channel)
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
                !dry && Reddit.reply(post, comment_str)
            catch e
                log("Comment generation/transmission failed: $e")
            end
        catch e
            log(e)
        end
    end

    # comments = Reddit.comments()
    # @async for comment in comments
    #     # TODO
    # end

    while true sleep(1) end
end

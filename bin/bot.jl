using OsuBot

import Base.log

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

const title_regex = r"(.+)\|(.+)-(.+)\[(.+)\].*"
const osu = "https://osu.ppy.sh"
const dry = in("DRY", ARGS) || in("TEST", ARGS)

if abspath(PROGRAM_FILE) == @__FILE__
    log("Running with dry=$(dry)")
    Reddit.login()
    log("Logged into Reddit")
    stream = Reddit.posts()
    for post in stream
        try
            !dry && post[:saved] && log("'$(post[:title])' is already saved") && continue
            post[:is_self] && log("'$(post[:title])' is a self post") && continue
            m = match(title_regex, post[:title])
            m == nothing && log("'$(post[:title])' is not a score post") && continue
            caps = strip.(m.captures)
            player = Osu.player(Utils.parse_player(caps[1]))
            isnull(player) && log("No player found for $(caps[1])") && continue
            map_str = "$(caps[2]) - $(caps[3]) [$(caps[4])]"
            beatmap = Utils.search(get(player), map_str)
            isnull(map) && warn("Proceeding without beatmap")
            comment_str = CommentMarkdown.build_comment(get(player), beatmap)
            log("Commenting on $(post[:title]): $comment_str")
            !dry && Reddit.reply_sticky(post, comment_str)
        catch e
            log(e)
        end
    end
end

"""
    from_title(title::AbstractString) -> String

Generate a comment string from a post title. Mostly for manual testing.
"""
function from_title(title::AbstractString)
    caps = strip.(match(title_regex, title).captures)
    player = Osu.player(Utils.parse_player(caps[1]))
    isnull(player) && error("Player $(caps[1]) not found")
    map_str = "$(caps[2]) - $(caps[3]) [$(caps[4])]"
    beatmap = Utils.search(get(player), map_str)
    isnull(beatmap) && warn("Beatmap not found")
    return CommentMarkdown.build_comment(get(player), beatmap)
end

using OsuBot

import Base.log

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

if abspath(PROGRAM_FILE) == @__FILE__
    const osu = "https://osu.ppy.sh"
    const dry = in("DRY", ARGS) || in("TEST", ARGS)
    log("Running with dry=$(dry)")
    const title_regex = r"(.+)\|(.+)-(.+)\[(.+)\].*"
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
            player = Osu.player(caps[1])
            isnull(player) && log("No player found for $(caps[1])") && continue
            map_str = "$(caps[2]) - $(caps[3]) [$(caps[4])]"
            beatmap = Nullable{OsuTypes.Beatmap}(Utils.search(get(player), map_str))
            isnull(map) && warn("Proceeding without beatmap")
            comment_str = CommentMarkdown.build_comment(get(player), beatmap)
            !dry && log("Commenting on $(post[:title]): $comment_str")
            !dry && Reddit.reply_sticky(post, comment_str)
        catch e
            log(e)
        end
    end
end

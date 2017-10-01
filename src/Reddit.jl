module Reddit

using PyCall

export login, posts, mentions, reply

const user_agent = ENV["REDDIT_USER_AGENT"]
const client_id = ENV["REDDIT_CLIENT_ID"]
const client_secret = ENV["REDDIT_CLIENT_SECRET"]
const username = ENV["REDDIT_USERNAME"]
const password = ENV["REDDIT_PASSWORD"]
const subreddit_name = ENV["REDDIT_SUBREDDIT"]

"""
    login() -> Void

Log in to Reddit and bind the global bot and subreddit variables.
"""
function login()
    @pyimport praw
    global bot = praw.Reddit(;
        user_agent=user_agent,
        client_id=client_id,
        client_secret=client_secret,
        username=username,
        password=password,
    )
    global subreddit = bot[:subreddit](subreddit_name)
    log("Logged into Reddit")
    return nothing
end

"""
    posts(channel::Channel) -> Void

Put new posts from the global subreddit into `channel` as they arrive. `praw` has a
streaming method built in, but new posts are picked up at slow/inconsistent intervals.
This function does not return, so wrap it in `@async`.
"""
function posts(channel::Channel)
    ids = String[]  # Ordered [oldest, ..., newest].
    while true
        new_posts = try
            reverse(collect(subreddit[:new]())) # Oldest posts first.
        catch e
            log(e)
            continue
        end
        for post in new_posts
            if !in(post[:id], ids)
                push!(ids, post[:id])
                length(ids) > 100 && shift!(ids)  # Remove the oldest entry.
                put!(channel, post)
            end
        end
        gc()  # Shouldn't be necessary; this is a PyCall bug (#436).
        sleep(10)
    end
end

"""
    mentions(channel::Channel) -> Void

Similar to `posts` but for comment mentions.
"""
function mentions(channel::Channel)
    ids = String[]
    while true
         comments = try
            reverse(collect(bot[:inbox][:mentions](; limit=50)))
        catch e
            log(e)
            continue
        end
        for comment in comments
            if !in(comment[:id], ids)
                push!(ids, comment[:id])
                length(ids) > 50 && shift!(ids)
                put!(channel, comment)
            end
        end
        gc()
        sleep(10)
    end
end

"""
    reply(obj::PyObject, comment::AbstractString; sticky::Bool=false) -> Void

Reply to a post or comment with `comment`, then upvote and save it.
"""
function reply(obj::PyObject, comment::AbstractString; sticky::Bool=false)
    comment = obj[:reply](comment)
    sticky && comment[:mod][:distinguish](; sticky=true)
    obj[:save]()
    obj[:upvote]()
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

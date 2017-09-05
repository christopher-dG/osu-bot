module Reddit

using PyCall
using YAML

export login, posts, comments, reply

"""
    login() -> Void

Log in to Reddit and bind the global bot and subreddit variables.
"""
function login()
    @pyimport praw
    config = YAML.load(open(joinpath(dirname(@__DIR__), "config.yml")))
    global bot = praw.Reddit(;
        map(pair -> Symbol(pair.first) => pair.second, config["reddit"])...,
    )
    global subreddit = bot[:subreddit](config["reddit"]["subreddit"])
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
        for post in reverse(collect(subreddit[:new]()))  # Oldest posts first.
            if !in(post[:id], ids)
                push!(ids, post[:id])
                length(ids) > 100 && shift!(ids)  # Remove the oldest entry.
                put!(channel, post)
            end
        end
        sleep(10)
    end
end

"""
    comments() -> PyObject

Get a generator to indefinitely stream comments from the global subreddit as they arrive.
"""
comments() = subreddit[:stream][:comments]()

"""
    reply(post::PyObject, comment::AbstractString) -> PyObject

Reply to `post` with `comment` and sticky it, then upvote and save the post.
"""
function reply(post::PyObject, comment::AbstractString)
    comment = post[:reply](comment)
    comment[:mod][:distinguish](; sticky=true)
    post[:save]()
    post[:upvote]()
end

log(msg) = (info("$(basename(@__FILE__)): $msg"); true)

end

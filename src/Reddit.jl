module Reddit

using PyCall
using YAML

@pyimport praw

"""
    login() -> Void

Authenticate a Reddit bot user defined by the global Reddit config.
"""
function login()
    config = YAML.load(open(joinpath(dirname(@__DIR__), "config.yml")))
    global bot = praw.Reddit(;
        map(pair -> Symbol(pair.first) => pair.second, config["reddit"])...,
    )
    global subreddit = bot[:subreddit](config["reddit"]["subreddit"])
    return nothing
end

"""
    posts() -> PyObject

Get a generator to indefinitely stream posts from the global subreddit as they arrive.
"""
posts() = subreddit[:stream][:submissions]()

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

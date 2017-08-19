module Reddit

using PyCall
using YAML

@pyimport praw

const config = map(
    pair -> Symbol(pair.first) => pair.second,
    YAML.load(open(joinpath(dirname(@__DIR__), "config.yml")))["reddit"],
)

"""
    login(config::Dict{Symbol, String}) -> PyObject

Return a Reddit bot user from `config` with keys `:user_agent`, `:client_id`,
`:client_secret`, `:username`, and `:password`.
"""
login() = praw.Reddit(; config...)

"""
    reply(post::PyObject, comment::AbstractString) -> PyObject

Reply to `post` with `comment` and return the new comment.
"""
reply(post::PyObject, comment::AbstractString) = post[:reply](comment)

"""
    sticky(comment::PyObject) -> Void

Distinguish and sticky `comment`.
"""
sticky(comment::PyObject) = comment[:mod][:distinguish](; sticky=true)

"""
    save(comment::PyObject) -> Void

Save `comment`.
"""
save(comment::PyObject) = comment[:save]()

log(msg::AbstractString) = info("$(basename(@__FILE__)): $msg")

end

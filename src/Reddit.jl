module Reddit

using PyCall
using YAML

@pyimport praw

"""
    login() -> PyObject

Return a Reddit bot user defined by the global Reddit config.
"""
function login()
    praw.Reddit(;
        map(
            pair -> Symbol(pair.first) => pair.second,
            YAML.load(open(joinpath(dirname(@__DIR__), "config.yml")))["reddit"],
        )...
    )
end

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

log(msg) = info("$(basename(@__FILE__)): $msg")

end

module OsuBot  # It's too bad 'osu!bot' breaks so many naming conventions.

export OsuTypes, Osu, Utils, Reddit, Oppai, CommentMarkdown

include("OsuTypes.jl")
include("Osu.jl")
include("Utils.jl")
include("Oppai.jl")
include("CommentMarkdown.jl")
include("Reddit.jl")

end

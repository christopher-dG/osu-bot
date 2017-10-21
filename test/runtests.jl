using OsuBot
using Base.Test

const data_dir = Pkg.dir("OsuBot", "test", "data")
beatmap = open(deserialize, joinpath(data_dir, "acidburst"))
player = open(deserialize, joinpath(data_dir, "yaong"))

const nomod = r"""
\A##### \[.+ - .+ \[.+\]\]\(https://osu\.ppy\.sh/b/\d+\) \[\(&#x2b07;\)\]\(https://osu\.ppy\.sh/d/\d+\) by \[.+\]\(https://osu\.ppy\.sh/u/.+\)
\*\*#1: \[.+\]\(https://osu\.ppy\.sh/u/\d+\) \(.*\d+\.\d+% - \d+pp\) \|\| [\d,]+x max combo \|\| .+ \|\| [\d,]+ plays\*\*

\|\s+CS\s+\|\s+AR\s+\|\s+OD\s+\|\s+HP\s+\|\s+SR\s+\|\s+BPM\s+\|\s+Length\s+\|\s+pp \(.+\)\s+\|
\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|
\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d]+\s+\|\s+[\d:]+\s+\|.+\|

\|\s+Player\s+\|\s+Rank\s+\|\s+pp\s+\|\s+Acc\s+\|\s+Playcount\s+\|\s+Top Play\s+\|
\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|
\|\s+\[.+\]\(https://osu.ppy\.sh/u/\d+\)\s+\|\s+#\d+&nbsp;\(#\d+&nbsp;.+\)\s+\|\s+[\d,]+\s+\|\s+[\d\.]+%\s+\|\s+[\d,]*\s+\|\s+\[.+ - .+ \[.+\]\]\(https://osu\.ppy\.sh/b/\d+\) .* &#124; [\d\.]+% &#124; \d+pp \|

\*\*\*

\^\(.+ - \)\[\^Source\]\(https://github\.com/christopher-dG/OsuBot\.jl\)\^\( \| \)\[\^Developer\]\(https://reddit\.com/u/PM_ME_DOG_PICS_PLS\)\^\( \| \)\[\^Usage\]\(https://github\.com/christopher-dG/OsuBot\.jl/blob/master/README\.md#summoning-the-bot\)\z"""

const modded = r"""
\A##### \[.+ - .+ \[.+\]\]\(https://osu\.ppy\.sh/b/\d+\) \[\(&#x2b07;\)\]\(https://osu\.ppy\.sh/d/\d+\) by \[.+\]\(https://osu\.ppy\.sh/u/.+\)
\*\*#1: \[.+\]\(https://osu\.ppy\.sh/u/\d+\) \(.*\d+\.\d+% - \d+pp\) \|\| [\d,]+x max combo \|\| .+ \|\| [\d,]+ plays\*\*

\|\s+\|\s+CS\s+\|\s+AR\s+\|\s+OD\s+\|\s+HP\s+\|\s+SR\s+\|\s+BPM\s+\|\s+Length\s+\|\s+pp \(.+\)\s+\|
\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|
\|\s+NoMod\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d]+\s+\|\s+[\d:]+\s+\|.+\|
\|\s+\+.+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d]+\s+\|\s+[\d:]+\s+\|.+\|

\|\s+Player\s+\|\s+Rank\s+\|\s+pp\s+\|\s+Acc\s+\|\s+Playcount\s+\|\s+Top Play\s+\|
\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|
\|\s+\[.+\]\(https://osu.ppy\.sh/u/\d+\)\s+\|\s+#\d+&nbsp;\(#\d+&nbsp;.+\)\s+\|\s+[\d,]+\s+\|\s+[\d\.]+%\s+\|\s+[\d,]*\s+\|\s+\[.+ - .+ \[.+\]\]\(https://osu\.ppy\.sh/b/\d+\) .* &#124; [\d\.]+% &#124; \d+pp \|

\*\*\*

\^\(.+ - \)\[\^Source\]\(https://github\.com/christopher-dG/OsuBot\.jl\)\^\( \| \)\[\^Developer\]\(https://reddit\.com/u/PM_ME_DOG_PICS_PLS\)\^\( \| \)\[\^Usage\]\(https://github\.com/christopher-dG/OsuBot\.jl/blob/master/README\.md#summoning-the-bot\)\z"""

const noplayer_nomod = r"""
\A##### \[.+ - .+ \[.+\]\]\(https://osu\.ppy\.sh/b/\d+\) \[\(&#x2b07;\)\]\(https://osu\.ppy\.sh/d/\d+\) by \[.+\]\(https://osu\.ppy\.sh/u/.+\)
\*\*#1: \[.+\]\(https://osu\.ppy\.sh/u/\d+\) \(.*\d+\.\d+% - \d+pp\) \|\| [\d,]+x max combo \|\| .+ \|\| [\d,]+ plays\*\*

\|\s+CS\s+\|\s+AR\s+\|\s+OD\s+\|\s+HP\s+\|\s+SR\s+\|\s+BPM\s+\|\s+Length\s+\|\s+pp \(.+\)\s+\|
\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|
\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d]+\s+\|\s+[\d:]+\s+\|.+\|

\*\*\*

\^\(.+ - \)\[\^Source\]\(https://github\.com/christopher-dG/OsuBot\.jl\)\^\( \| \)\[\^Developer\]\(https://reddit\.com/u/PM_ME_DOG_PICS_PLS\)\^\( \| \)\[\^Usage\]\(https://github\.com/christopher-dG/OsuBot\.jl/blob/master/README\.md#summoning-the-bot\)\z"""

const noplayer_modded = r"""
\A##### \[.+ - .+ \[.+\]\]\(https://osu\.ppy\.sh/b/\d+\) \[\(&#x2b07;\)\]\(https://osu\.ppy\.sh/d/\d+\) by \[.+\]\(https://osu\.ppy\.sh/u/.+\)
\*\*#1: \[.+\]\(https://osu\.ppy\.sh/u/\d+\) \(.*\d+\.\d+% - \d+pp\) \|\| [\d,]+x max combo \|\| .+ \|\| [\d,]+ plays\*\*

\|\s+\|\s+CS\s+\|\s+AR\s+\|\s+OD\s+\|\s+HP\s+\|\s+SR\s+\|\s+BPM\s+\|\s+Length\s+\|\s+pp \(.+\)\s+\|
\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|
\|\s+NoMod\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d]+\s+\|\s+[\d:]+\s+\|.+\|
\|\s+\+.+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d\.]+\s+\|\s+[\d]+\s+\|\s+[\d:]+\s+\|.+\|

\*\*\*

\^\(.+ - \)\[\^Source\]\(https://github\.com/christopher-dG/OsuBot\.jl\)\^\( \| \)\[\^Developer\]\(https://reddit\.com/u/PM_ME_DOG_PICS_PLS\)\^\( \| \)\[\^Usage\]\(https://github\.com/christopher-dG/OsuBot\.jl/blob/master/README\.md#summoning-the-bot\)\z"""

const nomap = r"""
\|\s+Player\s+\|\s+Rank\s+\|\s+pp\s+\|\s+Acc\s+\|\s+Playcount\s+\|\s+Top Play\s+\|
\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|:-+:\|
\|\s+\[.+\]\(https://osu.ppy\.sh/u/\d+\)\s+\|\s+#\d+&nbsp;\(#\d+&nbsp;.+\)\s+\|\s+[\d,]+\s+\|\s+[\d\.]+%\s+\|\s+[\d,]*\s+\|\s+\[.+ - .+ \[.+\]\]\(https://osu\.ppy\.sh/b/\d+\) .* &#124; [\d\.]+% &#124; \d+pp \|

\*\*\*

\^\(.+ - \)\[\^Source\]\(https://github\.com/christopher-dG/OsuBot\.jl\)\^\( \| \)\[\^Developer\]\(https://reddit\.com/u/PM_ME_DOG_PICS_PLS\)\^\( \| \)\[\^Usage\]\(https://github\.com/christopher-dG/OsuBot\.jl/blob/master/README\.md#summoning-the-bot\)\z"""

@testset "Utils.jl" begin
    @test Utils.mods_from_int(24) == [:HD, :HR]
    @test Utils.mods_from_int(72) == [:HD, :DT]
    @test Utils.mods_from_int(0) == Symbol[]
    @test Utils.mods_from_int(-1) == Symbol[]

    @test Utils.mods_to_int([:HD, :HR]) == 24
    @test Utils.mods_to_int([:HD, :DT]) == 72
    @test Utils.mods_to_int(Symbol[]) == 0

    @test Utils.mods_from_string("+HDDTHR") == 88
    @test Utils.mods_from_string("foo HD bar") == 8
    @test Utils.mods_from_string("hd,hr") == 24
    @test Utils.mods_from_string("something") == 0
    @test Utils.mods_from_string("foo | HD [] HR") == 16

    @test Utils.timestamp(10) == "00:10"
    @test Utils.timestamp(0) == "00:00"
    @test Utils.timestamp(-1) == "00:00"
    @test Utils.timestamp(3661) == "1:01:01"

    @test Utils.strfmt(12.3) == "12.3"
    @test Utils.strfmt(12.345) == "12.3"
    @test Utils.strfmt(12.345; precision=3) == "12.345"
    @test Utils.strfmt(12.345; precision=2) == "12.34"
    @test Utils.strfmt(12.000) == "12"
    @test Utils.strfmt(1234567.8) == "1,234,567.8"

    @test Utils.parse_player("foo") == "foo"
    @test Utils.parse_player("(foo) bar") == "bar"
    @test Utils.parse_player("foo (bar)") == "foo"
    @test Utils.parse_player("(foo) bar (baz)") == "bar"
    @test Utils.parse_player("foo (bar) baz") == "foo"
    @test Utils.parse_player("[foo] bar") == "[foo] bar"
    @test Utils.parse_player("[mania] foo") == "foo"
    @test Utils.parse_player("foo [ctb]") == "foo"
    @test Utils.parse_player("[std] foo [ctb]") == "foo"
    @test Utils.parse_player("foo [bar] [ctb]") == "foo [bar]"

    @test Utils.compare("foo", "foo")
    @test Utils.compare("foo", "FOO")
    @test Utils.compare("foo", "F O O")
    @test !Utils.compare("foo", "foobar")
end

@testset "Score post comment" begin
    s = CommentMarkdown.build_comment(
        Nullable(player),
        Nullable(beatmap),
        0,
        Nullable{Real}(),
        Nullable(OsuTypes.STD),
    )
    @test ismatch(nomod, s)
    s = CommentMarkdown.build_comment(
        Nullable(player),
        Nullable(beatmap),
        72,
        Nullable(98.5),
        Nullable(OsuTypes.STD),
    )
    @test ismatch(modded, s)
    s = CommentMarkdown.build_comment(
        Nullable{OsuTypes.User}(),
        Nullable(beatmap),
        0,
        Nullable{Real}(),
        Nullable{OsuTypes.Mode}(),
    )
    @test ismatch(noplayer_nomod, s)
    s = CommentMarkdown.build_comment(
        Nullable{OsuTypes.User}(),
        Nullable(beatmap),
        72,
        Nullable{Real}(),
        Nullable(OsuTypes.STD),
    )
    @test ismatch(noplayer_modded, s)
    s = CommentMarkdown.build_comment(
        Nullable(player),
        Nullable{OsuTypes.Beatmap}(),
        72,
        Nullable{Real}(),
        Nullable(OsuTypes.STD),
    )
    @test ismatch(nomap, s)
    @test_throws ErrorException CommentMarkdown.build_comment(
        Nullable{OsuTypes.User}(),
        Nullable{OsuTypes.Beatmap}(),
        0,
        Nullable{Real}(),
        Nullable{OsuTypes.Mode}()
    )

end

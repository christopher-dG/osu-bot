using OsuBot
using Base.Test

@testset "Utils.jl" begin
    @test Utils.mods_from_int(24) == [:HD, :HR]
    @test Utils.mods_from_int(72) == [:HD, :DT]
    @test Utils.mods_from_int(0) == Symbol[]
    @test Utils.mods_from_int(-1) == Symbol[]

    @test Utils.mods_to_int([:HD, :HR]) == 24
    @test Utils.mods_to_int([:HD, :DT]) == 72
    @test Utils.mods_to_int(Symbol[]) == 0

    @test Utils.mods_from_string("]+HDDTHR") == 88
    @test Utils.mods_from_string("]foo HD bar") == 8
    @test Utils.mods_from_string("]hd,hr") == 24
    @test Utils.mods_from_string("]something") == 0

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

end

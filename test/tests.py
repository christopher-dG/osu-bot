import markdown_strings as md
import osubot


def test_combine_mods():
    assert osubot.utils.combine_mods(1 >> 1) == ""
    assert osubot.utils.combine_mods(1 << 3 | 1 << 9 | 1 << 6) == "+HDNC"
    assert osubot.utils.combine_mods(1 << 3 | 1 << 4) == "+HDHR"
    assert osubot.utils.combine_mods(1 << 10 | 1 << 5 | 1 << 14) == "+FLPF"
    assert osubot.utils.combine_mods(1 << 6) == "+DT"


def test_getmods():
    assert osubot.context.getmods(" | - [ ] ") == 0
    assert osubot.context.getmods(" | - [ ] + ") == 0
    assert osubot.context.getmods(" | - [ ] +HD") == 8
    assert osubot.context.getmods(" | - [ ] HDHR +HD") == 8
    assert osubot.context.getmods(" | - [ ] HDHR HD") == 24
    assert osubot.context.getmods(" | - [ ] HD,HR HD") == 24
    assert osubot.context.getmods(" | - [ ] HD,HR +") == 24


def test_getmods_token():
    assert osubot.context.getmods_token("") == 0
    assert osubot.context.getmods_token("HDX") == 0
    assert osubot.context.getmods_token("hd") == 8
    assert osubot.context.getmods_token("HDHR") == 24
    assert osubot.context.getmods_token("HD,HR") == 24
    assert osubot.context.getmods_token("HDHRHR") == 24
    assert osubot.context.getmods_token("HDHRSCOREV2") == 536870936
    assert osubot.context.getmods_token("HDHRSV2DT") == 536871000


def test_accuracy():
    class Foo:
        def __init__(self, n3, n1, n5, ng, nk, nm):
            self.count300 = n3
            self.count100 = n1
            self.count50 = n5
            self.countgeki = ng
            self.countkatu = nk
            self.countmiss = nm

    assert abs(osubot.utils.accuracy(
        Foo(1344, 236, 2, 206, 82, 8),
        osubot.consts.std,
    ) - 89.5) < 0.005
    assert abs(osubot.utils.accuracy(
        Foo(2401, 436, 0, 13, 4, 92),
        osubot.consts.taiko,
    ) - 89.42) < 0.005
    assert abs(osubot.utils.accuracy(
        Foo(2655, 171, 435, 339, 3, 31),
        osubot.consts.ctb,
    ) - 98.97) < 0.005
    assert abs(osubot.utils.accuracy(
        Foo(902, 13, 4, 1882, 180, 16),
        osubot.consts.mania,
    ) - 97.06) < 0.005


def test_map_str():
    class Foo:
        def __init__(self, a, t, v):
            self.artist = a
            self.title = t
            self.version = v
    assert osubot.utils.map_str(Foo("foo", "bar", "baz")) == "foo - bar [baz]"
    assert osubot.utils.map_str(Foo("foo^2", "b*ar", "b_az")) == "foo\^2 - b\*ar [b\_az]"  # noqa


def test_str_to_timestamp():
    assert osubot.utils.str_to_timestamp(0) == "00:00"
    assert osubot.utils.str_to_timestamp(10) == "00:10"
    assert osubot.utils.str_to_timestamp(340) == "05:40"
    assert osubot.utils.str_to_timestamp(3940) == "01:05:40"


def test_nonbreaking():
    assert osubot.utils.nonbreaking("") == ""
    assert osubot.utils.nonbreaking("foobar") == "foobar"
    assert osubot.utils.nonbreaking("foo bar") == "foo%sbar" % osubot.consts.spc  # noqa
    assert osubot.utils.nonbreaking("foo-bar") == "foo%sbar" % osubot.consts.hyp  # noqa


def test_round_to_string():
    assert osubot.utils.round_to_str(1, 2) == "1"
    assert osubot.utils.round_to_str(1, 2, force=True) == "1.00"
    assert osubot.utils.round_to_str(1.4, 0) == "1"
    assert osubot.utils.round_to_str(1.4, 1) == "1.4"
    assert osubot.utils.round_to_str(1.4, 2) == "1.4"
    assert osubot.utils.round_to_str(1.4, 2, force=True) == "1.40"


def test_safe_call():
    def foo(x, y=0): return x / y
    assert osubot.utils.safe_call(foo, 0, y=1) == 0
    assert osubot.utils.safe_call(foo, 1, y=0) == []
    assert osubot.utils.safe_call(foo, 1, y=0, alt=10) == 10


def test_sep():
    assert osubot.utils.sep(0) == "0"
    assert osubot.utils.sep(1) == "1"
    assert osubot.utils.sep(999) == "999"
    assert osubot.utils.sep(9999) == "9,999"
    assert osubot.utils.sep(999999999) == "999,999,999"


def test_centre_table():
    t = md.table([["foobar"] * 10] * 5)
    lines = t.split("\n")
    centred = osubot.markdown.centre_table(t)
    centred_lines = centred.split("\n")
    assert centred_lines[1] == ":-:|:-:|:-:|:-:|:-:"
    assert lines[0] == centred_lines[0]
    assert "\n".join(lines[2:]) == "\n".join(centred_lines[2:])

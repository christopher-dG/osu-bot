import logging
import markdown_strings as md
import osubot
import re

logging.getLogger("urllib3").propagate = False


#                                         Map name               Map URL                           Download                   Download URL                               Mapper            Mapper URL             Rename                      Map counts                                                 GD name             GD URL                   GD map counts                                                       Mode  # noqa
approved_header = re.compile(
    """#### \[.+-.+\[.+\]\]\(https://osu\.ppy\.sh/b/\d+(:?\?m=\d)?\) \[\(&#x2b07;\)\]\(https://osu\.ppy\.sh/d/\d+ "Download this beatmap"\) by \[.+\]\(https://osu\.ppy\.sh/u/.+ "(?:Renamed to '.+': )?[\d,]+ ranked, [\d,]+ qualified, [\d,]+ loved, [\d,]+ unranked"\)(?: \(GD by \[.+\]\(https://osu.ppy.sh/u/\d+ "[\d,]+ ranked, [\d,]+ qualified, [\d,]+ loved, [\d,]+ unranked"\))? \|\| osu![a-z]+"""
)  # noqa
#                                       #1/2   Player         Player URL               pp           Rank         Country rank          Accuracy                     Playcount              Mods                  Accuracy             pp                  Max combo           Ranked status/year        Playcount  # noqa
approved_subheader = re.compile(
    """\*\*#[12]: \[.+\]\(https://osu\.ppy\.sh/u/\d+(?: "[\d,]+pp - rank #[\d,]+ \(#[\d,]+ [A-Z]{2}\) - \d{1,3}\.\d{2}% accuracy - [\d,]+ playcount")?\) \((?:\+(?:[A-Z2]{2})+ - )?\d{1,3}\.\d{2}%(?: - [\d,]+pp)?\) \|\| [\d,]+x max combo \|\| \w+(?: \(\d{4}\))? \|\| [\d,]+ plays\*\*"""
)  # noqa

#                                       Map name             Map URL                              Download                      Download URL                               Mapper            Mapper URL          Rename                       Map counts                                                   GD name            GD URL                  GD map counts  # noqa
unranked_header = re.compile(
    """#### \[.+-.+\[.+\]\]\(https://osu\.ppy\.sh/b/\d+(:?\?m=\d)?\) \[\(&#x2b07;\)\]\(https://osu\.ppy\.sh/d/\d+ "Download this beatmap"\) by \[.+\]\(https://osu\.ppy\.sh/u/.+ "(?:Renamed to '.+': )?[\d,]+ ranked, [\d,]+ qualified, [\d,]+ loved, [\d,]+ unranked"\)(?: \(GD by \[.+\]\(https://osu.ppy.sh/u/\d+ "[\d,]+ ranked, [\d,]+ qualified, [\d,]+ loved, [\d,]+ unranked"\))?"""
)  # noqa
#                                     Mode           Max combo           Ranked status  # noqa
unranked_subheader = re.compile(
    """osu![a-z]+ \|\| [\d,]+x max combo \|\| Unranked"""
)  # noqa

nomod_map_table_header = re.compile(
    """\
\|\s+CS\s+\|\s+AR\s+\|\s+OD\s+\|\s+HP\s+\|\s+SR\s+\|\s+BPM\s+\|\s+Length\s+\|\s+pp \(.+\)\s+\|
:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:\
"""
)  # noqa
#                                                  CS                    AR                     OD                     HP                      SR                    BPM             Length                  pp  # noqa
nomod_map_table_values = re.compile(
    """\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}\.\d{2}\s+\|\s+[\d,]+\s+\|\s+(?:\d{2}:)?\d{2}:\d{2}\s+\|\s+.+\s+\|"""
)  # noqa

modded_map_table_header = re.compile(
    """\
\|\s+\|\s+CS\s+\|\s+AR\s+\|\s+OD\s+\|\s+HP\s+\|\s+SR\s+\|\s+BPM\s+\|\s+Length\s+\|\s+pp \(.+\)\s+\|
:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:\
"""
)  # noqa

#               Mod             CS                        AR                     OD                       HP                      SR               BPM                  Length                 pp  # noqa
nomod = """\|\s+NoMod\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}\.\d{2}\s+\|\s+[\d,]+\s+\|\s+(?:\d{2}:)?\d{2}:\d{2}\s+\|\s+.+\s+\|"""  # noqa
#                    Mod                       CS                        AR                     OD                       HP                      SR               BPM              Length                 pp  # noqa
modded = """\|\s+\+(?:[A-Z2]{2})+\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}\.\d{2}\s+\|\s+[\d,]+\s+\|\s+(?:\d{2}:)?\d{2}:\d{2}\s+\|\s+.+\s+\|"""  # noqa
modded_map_table_values = re.compile("%s\n%s" % (nomod, modded))

player_table_header = re.compile(
    """\
\|\s+Player\s+\|\s+Rank\s+\|\s+pp\s+\|\s+Accuracy\s+\|(?:\s+Playstyle\s+\|)?\s+Playcount\s+\|\s+Top Play\s+\|
:-:\|:-:\|:-:\|:-:\|:-:\|:-:(?:\|:-:)?\
"""
)  # noqa

#                                         Name             URL                         Old name                       Rank                Country rank                pp            Accuracy                Playstyle          Playcount          Top plau map                 Map URL                       Map SR                 Map CS             Map AR              Map OD               Map HP            Map BPM         Map length                        Mods                             Accuracy                            pp  # noqa
player_table_values = re.compile(
    """\|\s+\[.+\]\(https://osu\.ppy\.sh/u/\d+(?: "Previously known as '.+'")?\)\s+\|\s+#[\d,]+&nbsp;\(#[\d,]+&nbsp;[A-Z]{2}\)\s+\|\s+[\d,]+\s+\|\s+\d{1,3}\.\d{2}%\s+\|(?:\s+[A-Z\+]+\s+\|)?\s+[\d,]+\s+\|\s+\[.+#x2011;.+\[.+\]\]\(https://osu\.ppy\.sh/b/\d+(?:\?m=\d)?(?: "SR\d{1,2}\.\d{2} - CS\d{1,2}(?:\.\d)? - AR\d{1,2}(?:\.\d)? - OD\d{1,2}(?:\.\d)? - HP\d{1,2}(?:\.\d)? - [\d,]+BPM - (?:\d{2}:)?\d{2}:\d{2}")?\) (?:\+(?:[A-Z2]{2})+&nbsp;&#124;&nbsp;)?\d{1,3}\.\d{2}%&nbsp;&#124;&nbsp;[\d,]+pp\s+\|"""
)  # noqa

#                          Meme                         Repo                                                             Profile  # noqa
footer = re.compile(
    """\^\(.+ – \)\[\^Source\]\(https://github\.com/christopher-dG/osu-bot\)\^\( \| \)\[\^Developer\]\(https://reddit\.com/u/PM_ME_DOG_PICS_PLS\)"""
)  # noqa

std_t = "Cookiezi | xi - FREEDOM DiVE [FOUR DIMENSIONS] +HDHR 99.83%"
std_unranked_t = (
    "Mlaw | t+pazolite with Kabocha - Elder Dragon Legend [???] 99.95%"  # noqa
)
taiko_t = "applerss | KASAI HARCORES - Cycle Hit [Strike] HD,DT 96,67%"
ctb_t = "[ctb] Dusk | onoken - P8107 [Nervous Breakdown] +HR 99.92%"
mania_t = "(mania) WindyS | LeaF - Doppelganger [Alter Ego] 98.53%"


def try_assert(f, expected, *args, attr=None, **kwargs):
    try:
        result = f(*args, **kwargs)
        if attr:
            result = result.__getattribute__(attr)
        assert result == expected
    except Exception as e:
        assert False, "%s: %s" % (f.__name__, e)


def _assert_match(regex, text):
    assert regex.search(text), "\nText:\n%s\nRegex:\n%s" % (text, regex.pattern)  # noqa


def isapprox(x, y, t=0.005):
    return abs(x - y) < t


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
    assert osubot.context.getmods_token("HDX") is None
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

    assert isapprox(
        osubot.utils.accuracy(Foo(1344, 236, 2, 206, 82, 8), osubot.consts.std,), 89.5,
    )
    assert isapprox(
        osubot.utils.accuracy(Foo(2401, 436, 0, 13, 4, 92), osubot.consts.taiko,),
        89.42,
    )
    assert isapprox(
        osubot.utils.accuracy(Foo(2655, 171, 435, 339, 3, 31), osubot.consts.ctb,),
        98.97,
    )
    assert isapprox(
        osubot.utils.accuracy(Foo(902, 13, 4, 1882, 180, 16), osubot.consts.mania,),
        97.06,
    )


def test_map_str():
    class Foo:
        def __init__(self, a, t, v):
            self.artist = a
            self.title = t
            self.version = v

    assert osubot.utils.map_str(Foo("foo", "bar", "baz")) == "foo - bar [baz]"


def test_s_to_ts():
    assert osubot.utils.s_to_ts(0) == "00:00"
    assert osubot.utils.s_to_ts(10) == "00:10"
    assert osubot.utils.s_to_ts(340) == "05:40"
    assert osubot.utils.s_to_ts(3940) == "01:05:40"


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
    assert osubot.utils.round_to_str(1.01, 1) == "1"
    assert osubot.utils.round_to_str(0.9997, 3) == "1"
    assert osubot.utils.round_to_str(4.1, 1) == "4.1"


def test_safe_call():
    def foo(x, y=0):
        return x / y

    assert osubot.utils.safe_call(foo, 0, y=1) == 0
    assert osubot.utils.safe_call(foo, 1, y=0) is None
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


def test_compare():
    assert osubot.utils.compare("", "")
    assert not osubot.utils.compare("foo", "bar")
    assert osubot.utils.compare("foo bar", "foobar")
    assert osubot.utils.compare("foobar", "FOOBAR")
    assert osubot.utils.compare("foo&bar", "FOO&amp;BAR")
    assert osubot.utils.compare('foo"bar', "FOO&quot;BAR")
    assert osubot.utils.compare("foo", "fob")


def test_safe_url():
    assert osubot.utils.safe_url("") == ""
    assert osubot.utils.safe_url("foobar") == "foobar"
    assert osubot.utils.safe_url(osubot.consts.osu_key) == "###"
    assert (
        osubot.utils.safe_url("?k=%s&b=1" % osubot.consts.osu_key) == "?k=###&b=1"
    )  # noqa


def test_escape():
    assert osubot.utils.escape("") == ""
    assert osubot.utils.escape("a*b_c^d~e") == "a\*b\_c\^d\~e"


def test_is_ignored():
    assert not osubot.utils.is_ignored(1 << 3)
    assert osubot.utils.is_ignored(1 << 7)
    assert osubot.utils.is_ignored(1 << 11)
    assert not osubot.utils.is_ignored(1 << 3 | 1 << 7)
    assert osubot.utils.is_ignored(1 << 7 | 1 << 11)
    assert not osubot.utils.is_ignored(1 << 3 | 1 << 7 | 1 << 11)


def test_changes_diff():
    assert osubot.utils.changes_diff(1 << 4)
    assert not osubot.utils.changes_diff(1 << 3)
    assert osubot.utils.changes_diff(1 << 3 | 1 << 4)
    assert not osubot.utils.changes_diff(1 << 2 | 1 << 0 | 1 << 10)
    assert osubot.utils.changes_diff(1 << 2 | 1 << 0 | 1 << 10 | 1 << 6)


def test_matched_bracket_contents():
    func = osubot.utils.matched_bracket_contents
    assert func("") is None
    assert func("[foo]") == "foo"
    assert func("[foo [bar]]") == "foo [bar]"
    assert func("[foo [bar] baz [qux]]") == "foo [bar] baz [qux]"
    assert func("[foo bar [ baz]") is None


def test_strip_annots():
    assert osubot.context.strip_annots("") == ""
    assert osubot.context.strip_annots("foo") == "FOO"
    assert osubot.context.strip_annots("foo (bar)") == "FOO"
    assert osubot.context.strip_annots("[foo] bar") == "[FOO] BAR"
    assert osubot.context.strip_annots("[unnoticed] foo") == "FOO"
    assert osubot.context.strip_annots("(foo) bar (baz)") == "BAR"
    assert osubot.context.strip_annots("[mania] [foo] bar") == "[FOO] BAR"

    # NOTE: Most of the tests below are network dependent,
    # so spurious failures are possible.


def test_getplayer():
    try_assert(osubot.context.getplayer, 124493, std_t, attr="user_id")


def test_getmap():
    try_assert(osubot.context.getmap, 129891, std_t, attr="beatmap_id")


def test_getmode():
    assert osubot.context.getmode(ctb_t) == osubot.consts.ctb
    assert osubot.context.getmode(mania_t) == osubot.consts.mania


def test_getacc():
    assert osubot.context.getacc(std_t) == 99.83
    assert osubot.context.getacc(taiko_t) == 96.67


def test_getguestmapper():
    try_assert(
        osubot.context.getguestmapper,
        "toybot",
        ". | . - . [toybot's .]",
        attr="username",
    )
    assert not osubot.context.getguestmapper(".|.-.[Insane]")


def test_std_end2end():
    ctx, reply = osubot.scorepost(std_t)
    assert str(ctx) == "\n".join(
        [
            "Context:",
            "> Player:        Cookiezi",
            "> Beatmap:       xi - FREEDOM DiVE [FOUR DIMENSIONS]",
            "> Mode:          osu!standard",
            "> Mods:          +HDHR",
            "> Accuracy:      99.83%",
            "> Guest mapper:  None",
        ]
    )
    _assert_match(approved_header, reply)
    _assert_match(approved_subheader, reply)
    _assert_match(modded_map_table_header, reply)
    _assert_match(modded_map_table_values, reply)
    _assert_match(player_table_header, reply)
    _assert_match(player_table_values, reply)
    _assert_match(footer, reply)


def test_std_unranked_end2end():
    ctx, reply = osubot.scorepost(std_unranked_t)
    assert str(ctx) == "\n".join(
        [
            "Context:",
            "> Player:        Mlaw",
            "> Beatmap:       t+pazolite with Kabocha - Elder Dragon Legend [???]",
            "> Mode:          osu!standard",
            "> Mods:          NoMod",
            "> Accuracy:      99.95%",
            "> Guest mapper:  None",
        ]
    )
    _assert_match(unranked_header, reply)
    _assert_match(unranked_subheader, reply)
    _assert_match(nomod_map_table_header, reply)
    _assert_match(nomod_map_table_values, reply)
    _assert_match(player_table_header, reply)
    _assert_match(player_table_values, reply)
    _assert_match(footer, reply)


def test_taiko_end2end():
    ctx, reply = osubot.scorepost(taiko_t)
    assert str(ctx) == "\n".join(
        [
            "Context:",
            "> Player:        applerss",
            "> Beatmap:       KASAI HARCORES - Cycle Hit [Strike]",
            "> Mode:          osu!taiko",
            "> Mods:          +HDDT",
            "> Accuracy:      96.67%",
            "> Guest mapper:  None",
        ]
    )
    _assert_match(approved_header, reply)
    _assert_match(approved_subheader, reply)
    _assert_match(modded_map_table_header, reply)
    _assert_match(modded_map_table_values, reply)
    _assert_match(player_table_header, reply)
    _assert_match(player_table_values, reply)
    _assert_match(footer, reply)


def test_ctb_end2end():
    ctx, reply = osubot.scorepost(ctb_t)
    assert str(ctx) == "\n".join(
        [
            "Context:",
            "> Player:        Dusk",
            "> Beatmap:       onoken - P8107 [Nervous Breakdown]",
            "> Mode:          osu!catch",
            "> Mods:          +HR",
            "> Accuracy:      99.92%",
            "> Guest mapper:  None",
        ]
    )
    _assert_match(approved_header, reply)
    _assert_match(approved_subheader, reply)
    _assert_match(modded_map_table_header, reply)
    _assert_match(modded_map_table_values, reply)
    _assert_match(player_table_header, reply)
    _assert_match(player_table_values, reply)
    _assert_match(footer, reply)
    assert "osu!catch pp is experimental" in reply


def test_mania_end2end():
    ctx, reply = osubot.scorepost(mania_t)
    assert str(ctx) == "\n".join(
        [
            "Context:",
            "> Player:        WindyS",
            "> Beatmap:       LeaF - Doppelganger [Alter Ego]",
            "> Mode:          osu!mania",
            "> Mods:          NoMod",
            "> Accuracy:      98.53%",
            "> Guest mapper:  None",
        ]
    )
    _assert_match(approved_header, reply)
    _assert_match(approved_subheader, reply)
    _assert_match(nomod_map_table_header, reply)
    _assert_match(nomod_map_table_values, reply)
    _assert_match(player_table_header, reply)
    _assert_match(player_table_values, reply)
    _assert_match(footer, reply)
    assert "osu!mania pp is experimental" in reply


test_getmap.net = 1
test_getplayer.net = 1
test_getguestmapper.net = 1
test_std_end2end.net = 1
test_std_unranked_end2end.net = 1
test_taiko_end2end.net = 1
test_ctb_end2end.net = 1
test_mania_end2end.net = 1

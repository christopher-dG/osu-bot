import logging
import markdown_strings as md
import osubot
import re

logging.getLogger("urllib3").propagate = False

std_t = "Cookiezi | xi - FREEDOM DiVE [FOUR DIMENSIONS] +HDHR 99.83%"
taiko_t = "applerss | KASAI HARCORES - Cycle Hit [Strike] HD,DT 96,67%"
ctb_t = "[ctb] Dusk | onoken - P8107 [Nervous Breakdown] +HR 99.92%"
mania_t = "(mania) WindyS | LeaF - Doppelganger [Alter Ego] 98.53%"
map_player_mods_pp_re = re.compile("""\
#### \[.+-.+\[.+\]\]\(https:\/\/osu\.ppy\.sh\/b\/\d+(:?\?m=\d)?\) \[\(&#x2b07;\)\]\(https:\/\/osu\.ppy\.sh\/d\/\d+\) by \[.+\]\(https:\/\/osu\.ppy\.sh\/u\/.+ "(?:Renamed to '.+': )?[\d,]+ ranked, [\d,]+ qualified, [\d,]+ loved, [\d,]+ unranked"\)(?: \|\| osu![a-z]+)?
\*\*#[12]: \[.+\]\(https:\/\/osu\.ppy\.sh\/u\/\d+(?: "[\d,]+pp - rank #[\d,]+ \(#[\d,]+ [A-Z]{2}\) - \d{1,3}\.\d{2}% acc - [\d,]+ playcount")?\) \((?:\+(?:[A-Z2]{2})+ - )?\d{1,3}\.\d{2}%(?: - [\d,]+pp)?\) \|\| [\d,]+x max combo \|\| \w+ \((.+)\) \|\| [\d,]+ plays\*\*

\|\s+\|\s+CS\s+\|\s+AR\s+\|\s+OD\s+\|\s+HP\s+\|\s+SR\s+\|\s+BPM\s+\|\s+Length\s+\|\s+pp \(.+\)\s+\|
:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:
\|\s+NoMod\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}\.\d{2}\s+\|\s+[\d,]+\s+\|\s+(?:\d{2}:)?\d{2}:\d{2}\s+\|\s+.+\s+\|
\|\s+\+(?:[A-Z2]{2})+\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}\.\d{2}\s+\|\s+[\d,]+\s+\|\s+(?:\d{2}:)?\d{2}:\d{2}\s+\|\s+.+\s+\|

\|\s+Player\s+\|\s+Rank\s+\|\s+pp\s+\|\s+Acc\s+\|\s+Playcount\s+\|\s+Top Play\s+\|
:-:\|:-:\|:-:\|:-:\|:-:\|:-:
\|\s+\[.+\]\(https:\/\/osu\.ppy\.sh\/u\/\d+\)\s+\|\s+#[\d,]+&nbsp;\(#[\d,]+&nbsp;[A-Z]{2}\)\s+\|\s+[\d,]+\s+\|\s+\d{1,3}\.\d{2}%\s+\|\s+[\d,]+\s+\|\s+\[.+#x2011;.+\[.+\]\]\(https:\/\/osu\.ppy\.sh\/b\/\d+(?:\?m=\d)?(?: "SR\d{1,2}\.\d{2} - CS\d{1,2}(?:\.\d)? - AR\d{1,2}(?:\.\d)? - OD\d{1,2}(?:\.\d)? - HP\d{1,2}(?:\.\d)? - [\d,]+BPM - (?:\d{2}:)?\d{2}:\d{2}")?\) (?:\+(?:[A-Z2]{2})+&nbsp;&#124;&nbsp;)?\d{1,3}\.\d{2}%&nbsp;&#124;&nbsp;[\d,]+pp\s+\|

\*\*\*

\^\(.+ – \)\[\^Source\]\(https:\/\/github\.com\/christopher-dG\/osu-bot-serverless\)\^\( \| \)\[\^Developer\]\(https:\/\/reddit\.com\/u\/PM_ME_DOG_PICS_PLS\)\
""")  # noqa
map_player_nomods_pp_re = re.compile("""\
#### \[.+-.+\[.+\]\]\(https:\/\/osu\.ppy\.sh\/b\/\d+(:?\?m=\d)?\) \[\(&#x2b07;\)\]\(https:\/\/osu\.ppy\.sh\/d\/\d+\) by \[.+\]\(https:\/\/osu\.ppy\.sh\/u\/.+ "(?:Renamed to '.+': )?[\d,]+ ranked, [\d,]+ qualified, [\d,]+ loved, [\d,]+ unranked"\)(?: \|\| osu![a-z]+)?
\*\*#[12]: \[.+\]\(https:\/\/osu\.ppy\.sh\/u\/\d+(?: "[\d,]+pp - rank #[\d,]+ \(#[\d,]+ [A-Z]{2}\) - \d{1,3}\.\d{2}% acc - [\d,]+ playcount")?\) \((?:\+(?:[A-Z2]{2})+ - )?\d{1,3}\.\d{2}%(?: - [\d,]+pp)?\) \|\| [\d,]+x max combo \|\| \w+ \((.+)\) \|\| [\d,]+ plays\*\*

\|\s+CS\s+\|\s+AR\s+\|\s+OD\s+\|\s+HP\s+\|\s+SR\s+\|\s+BPM\s+\|\s+Length\s+\|\s+pp \(.+\)\s+\|
:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:
\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}\.\d{2}\s+\|\s+[\d,]+\s+\|\s+(?:\d{2}:)?\d{2}:\d{2}\s+\|\s+.+\s+\|

\|\s+Player\s+\|\s+Rank\s+\|\s+pp\s+\|\s+Acc\s+\|\s+Playcount\s+\|\s+Top Play\s+\|
:-:\|:-:\|:-:\|:-:\|:-:\|:-:
\|\s+\[.+\]\(https:\/\/osu\.ppy\.sh\/u\/\d+\)\s+\|\s+#[\d,]+&nbsp;\(#[\d,]+&nbsp;[A-Z]{2}\)\s+\|\s+[\d,]+\s+\|\s+\d{1,3}\.\d{2}%\s+\|\s+[\d,]+\s+\|\s+\[.+#x2011;.+\[.+\]\]\(https:\/\/osu\.ppy\.sh\/b\/\d+(?:\?m=\d)?(?: "SR\d{1,2}\.\d{2} - CS\d{1,2}(?:\.\d)? - AR\d{1,2}(?:\.\d)? - OD\d{1,2}(?:\.\d)? - HP\d{1,2}(?:\.\d)? - [\d,]+BPM - (?:\d{2}:)?\d{2}:\d{2}")?\)(?: \+(?:[A-Z2]{2})+&nbsp;&#124;&nbsp;)?\d{1,3}\.\d{2}%&nbsp;&#124;&nbsp;[\d,]+pp\s+\|

\*\*\*

\^\(.+ – \)\[\^Source\]\(https:\/\/github\.com\/christopher-dG\/osu-bot-serverless\)\^\( \| \)\[\^Developer\]\(https:\/\/reddit\.com\/u\/PM_ME_DOG_PICS_PLS\)\
""")  # noqa
map_noplayer_mods_pp_re = re.compile("""\
#### \[.+-.+\[.+\]\]\(https:\/\/osu\.ppy\.sh\/b\/\d+(:?\?m=\d)?\) \[\(&#x2b07;\)\]\(https:\/\/osu\.ppy\.sh\/d\/\d+\) by \[.+\]\(https:\/\/osu\.ppy\.sh\/u\/.+ "(?:Renamed to '.+': )?[\d,]+ ranked, [\d,]+ qualified, [\d,]+ loved, [\d,]+ unranked"\)(?: \|\| osu![a-z]+)?
\*\*#[12]: \[.+\]\(https:\/\/osu\.ppy\.sh\/u\/\d+(?: "[\d,]+pp - rank #[\d,]+ \(#[\d,]+ [A-Z]{2}\) - \d{1,3}\.\d{2}% acc - [\d,]+ playcount")?\) \((?:\+(?:[A-Z2]{2})+ - )?\d{1,3}\.\d{2}%(?: - [\d,]+pp)?\) \|\| [\d,]+x max combo \|\| \w+ \((.+)\) \|\| [\d,]+ plays\*\*

\|\s+\|\s+CS\s+\|\s+AR\s+\|\s+OD\s+\|\s+HP\s+\|\s+SR\s+\|\s+BPM\s+\|\s+Length\s+\|\s+pp \(.+\)\s+\|
:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:\|:-:
\|\s+NoMod\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}\.\d{2}\s+\|\s+[\d,]+\s+\|\s+(?:\d{2}:)?\d{2}:\d{2}\s+\|\s+.+\s+\|
\|\s+\+(?:[A-Z2]{2})+\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}(?:\.\d)?\s+\|\s+\d{1,2}\.\d{2}\s+\|\s+[\d,]+\s+\|\s+(?:\d{2}:)?\d{2}:\d{2}\s+\|\s+.+\s+\|

\*\*\*

\^\(.+ – \)\[\^Source\]\(https:\/\/github\.com\/christopher-dG\/osu-bot-serverless\)\^\( \| \)\[\^Developer\]\(https:\/\/reddit\.com\/u\/PM_ME_DOG_PICS_PLS\)\
""")  # noqa
nomap_player_re = re.compile("""\
\|\s+Player\s+\|\s+Rank\s+\|\s+pp\s+\|\s+Acc\s+\|\s+Playcount\s+\|\s+Top Play\s+\|
:-:\|:-:\|:-:\|:-:\|:-:\|:-:
\|\s+\[.+\]\(https:\/\/osu\.ppy\.sh\/u\/\d+\)\s+\|\s+#[\d,]+&nbsp;\(#[\d,]+&nbsp;[A-Z]{2}\)\s+\|\s+[\d,]+\s+\|\s+\d{1,3}\.\d{2}%\s+\|\s+[\d,]+\s+\|\s+\[.+#x2011;.+\[.+\]\]\(https:\/\/osu\.ppy\.sh\/b\/\d+(?:\?m=\d)?(?: "SR\d{1,2}\.\d{2} - CS\d{1,2}(?:\.\d)? - AR\d{1,2}(?:\.\d)? - OD\d{1,2}(?:\.\d)? - HP\d{1,2}(?:\.\d)? - [\d,]+BPM - (?:\d{2}:)?\d{2}:\d{2}")?\)(?: \+(?:[A-Z2]{2})+&nbsp;&#124;&nbsp;)?\d{1,3}\.\d{2}%&nbsp;&#124;&nbsp;[\d,]+pp\s+\|

\*\*\*

\^\(.+ – \)\[\^Source\]\(https:\/\/github\.com\/christopher-dG\/osu-bot-serverless\)\^\( \| \)\[\^Developer\]\(https:\/\/reddit\.com\/u\/PM_ME_DOG_PICS_PLS\)\
""")  # noqa


def try_assert(f, expected, *args, attr=None, **kwargs):
    try:
        result = f(*args, **kwargs)
        if attr:
            result = result.__getattribute__(attr)
        assert result == expected
    except Exception as e:
        assert False, "%s: %s" % (f.__name__, e)


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

    assert isapprox(
        osubot.utils.accuracy(
            Foo(1344, 236, 2, 206, 82, 8),
            osubot.consts.std,
        ),
        89.5,
    )
    assert isapprox(
        osubot.utils.accuracy(
            Foo(2401, 436, 0, 13, 4, 92),
            osubot.consts.taiko,
        ),
        89.42,
    )
    assert isapprox(
        osubot.utils.accuracy(
            Foo(2655, 171, 435, 339, 3, 31),
            osubot.consts.ctb,
        ),
        98.97,
    )
    assert isapprox(
        osubot.utils.accuracy(
            Foo(902, 13, 4, 1882, 180, 16),
            osubot.consts.mania,
        ),
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


def test_compare():
    assert osubot.utils.compare("", "")
    assert not osubot.utils.compare("foo", "bar")
    assert osubot.utils.compare("foo bar", "foobar")
    assert osubot.utils.compare("foobar", "FOOBAR")
    assert osubot.utils.compare("foo&bar", "FOO&amp;BAR")
    assert osubot.utils.compare("foo\"bar", "FOO&quot;BAR")
    assert osubot.utils.compare("foo", "fob")


def test_safe_url():
    assert osubot.utils.safe_url("") == ""
    assert osubot.utils.safe_url("foobar") == "foobar"
    assert osubot.utils.safe_url(osubot.consts.osu_key) == "###"
    assert osubot.utils.safe_url(osubot.consts.osusearch_key) == "###"
    assert osubot.utils.safe_url("?k=%s&b=1" % osubot.consts.osu_key) == "?k=###&b=1"  # noqa


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
    # Need regex lookbehind for these.
    # assert osubot.context.strip_annots("(foo) bar (baz)") == "BAR"
    # assert osubot.context.strip_annots("[mania] [foo] bar") == "[FOO] BAR"

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


def test_std_end2end():
    ctx, reply = osubot.scorepost(std_t)
    assert str(ctx) == "\n".join([
        "Context:",
        "> Player:   Cookiezi",
        "> Beatmap:  xi - FREEDOM DiVE [FOUR DIMENSIONS]",
        "> Mode:     osu!standard",
        "> Mods:     +HDHR",
        "> Acc:      99.83%",
    ])
    assert map_player_mods_pp_re.match(reply)


def test_taiko_end2end():
    ctx, reply = osubot.scorepost(taiko_t)
    assert str(ctx) == "\n".join([
        "Context:",
        "> Player:   applerss",
        "> Beatmap:  KASAI HARCORES - Cycle Hit [Strike]",
        "> Mode:     osu!taiko",
        "> Mods:     +HDDT",
        "> Acc:      96.67%",
    ])
    assert map_player_mods_pp_re.match(reply)


def test_ctb_end2end():
    ctx, reply = osubot.scorepost(ctb_t)
    assert str(ctx) == "\n".join([
        "Context:",
        "> Player:   Dusk",
        "> Beatmap:  onoken - P8107 [Nervous Breakdown]",
        "> Mode:     osu!catch",
        "> Mods:     +HR",
        "> Acc:      99.92%",
    ])
    assert map_player_nomods_pp_re.match(reply)
    assert "osu!catch pp is experimental" in reply


def test_mania_end2end():
    ctx, reply = osubot.scorepost(mania_t)
    assert str(ctx) == "\n".join([
        "Context:",
        "> Player:   WindyS",
        "> Beatmap:  LeaF - Doppelganger [Alter Ego]",
        "> Mode:     osu!mania",
        "> Mods:     NoMod",
        "> Acc:      98.53%",
    ])
    assert map_player_nomods_pp_re.match(reply)
    assert "osu!mania pp is experimental" in reply


def test_cached():
    @osubot.utils.cached
    def foo(f, *args, **kwargs): pass
    def bar(*args, **kwargs): return True  # noqa
    def baz(*args, **kwargs): return True  # noqa

    foo(bar, 1)
    assert foo.cache[bar]["hits"] == 0
    assert foo.cache[bar]["misses"] == 1
    foo(bar, 1, "baz")
    assert foo.cache[bar]["hits"] == 0
    assert foo.cache[bar]["misses"] == 2
    foo(bar, 1, "BAZ")
    assert foo.cache[bar]["hits"] == 1
    assert foo.cache[bar]["misses"] == 2

    foo(bar, x=1)
    assert foo.cache[bar]["hits"] == 1
    assert foo.cache[bar]["misses"] == 3
    foo(bar, x=2)
    foo(bar, x=2)
    assert foo.cache[bar]["hits"] == 2
    assert foo.cache[bar]["misses"] == 4
    foo(bar, x=1, y="baz")
    foo(bar, x=1, y="BAZ")
    assert foo.cache[bar]["hits"] == 3
    assert foo.cache[bar]["misses"] == 5

    foo(bar, 1, 2, "baz", x=1, y=2, z="qux")
    foo(bar, 1, 2, "BAZ", x=1, z="qux", y=2)
    assert foo.cache[bar]["hits"] == 4
    assert foo.cache[bar]["misses"] == 6

    foo(baz, 1)
    assert foo.cache[baz]["hits"] == 0
    assert foo.cache[baz]["misses"] == 1

    assert foo.cache_summary() == {
        "bar": {"hits": 4, "misses": 6, "length": 6},
        "baz": {"hits": 0, "misses": 1, "length": 1},
    }

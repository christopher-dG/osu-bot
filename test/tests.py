import osubot


def test_combine_mods():
    assert osubot.utils.combine_mods(1 >> 1) == "NoMod"
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

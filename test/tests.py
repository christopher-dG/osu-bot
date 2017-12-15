import osubot


def test_combine_mods():
    assert osubot.combine_mods(1 >> 1) == "NoMod"
    assert osubot.combine_mods(1 << 3 | 1 << 9 | 1 << 6) == "+HDNC"
    assert osubot.combine_mods(1 << 3 | 1 << 4) == "+HDHR"
    assert osubot.combine_mods(1 << 10 | 1 << 5 | 1 << 14) == "+FLPF"

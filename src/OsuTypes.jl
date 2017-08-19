"""
Types that represent concepts/objects in osu!.
"""
module OsuTypes

export Beatmap, Player, Score, Mods

struct Beatmap
end

struct Player
end

struct Score
end

@enum Mode STD TAIKO CTB MANIA

# https://github.com/ppy/osu-api/wiki#mods
@enum(
    Mod,
    NOMOD=1 >> 1,
    NF=1 << 0,
    EZ=1 << 1,
    NOVID=1 << 2,
    HD=1 << 3,
    HR= 1 << 4,
    SD=1 << 5,
    DT=1 << 6,
    RL=1 << 7,
    HT=1 << 8,
    NC=1 << 6 + 1 << 9,  # DT is always set along with NC.
    FL=1 << 10,
    AT=1 << 11,
    SO=1 << 12,
    AP=1 << 13,
    PF=1 << 5 + 1 << 14,  # SD is always set along with PF.
    K4=1 << 15,
    K5=1 << 16,
    K6=1 << 17,
    K7=1 << 18,
    K8=1 << 19,
    KMOD=1 << 15 | 1 << 16 | 1 << 17 | 1 << 18 | 1 << 19,
    FADEIN=1 << 20,
    RANDOM=1 << 21,
    LAST=1 << 22,
    FREEMOD=1 << 0 | 1 << 1 | 1 << 3 | 1 << 4 | 1 << 5 | 1 << 10 | 1 << 20 | 1 << 7 | 1 << 11 | 1 << 12 | 1 << 15 | 1 << 16 | 1 << 17 | 1 << 18 | 1 << 19,
    K9=1 << 24,
    K10=1 << 25,
    K1=1 << 26,
    K3=1 << 27,
    K2=1 << 28,
)

log(msg::AbstractString) = info("$(basename(@__FILE__)): $msg")

end

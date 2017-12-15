import os
import osuapi
import re

# Web stuff
osu_key = os.environ["OSU_API_KEY"]
osu_api = osuapi.OsuApi(osu_key, connector=osuapi.ReqConnector())
osusearch_url = "https://osusearch.com/api/search"
osusearch_key = os.environ["OSUSEARCH_API_KEY"]

# Reddit stuff
reddit_user = "osu-bot"
reddit_password = os.environ["REDDIT_PASSWORD"]
reddit_client_id = os.environ["REDDIT_CLIENT_ID"]
reddit_client_secret = os.environ["REDDIT_CLIENT_SECRET"]

# Regex stuff
title_re = re.compile("(.+)\|(.+)-(.+)\[(.+)\]")
map_re = re.compile(".+\|(.+-.+\[.+\])")
map_pieces_re = re.compile(".+\|(.+)-(.+)\[(.+)\]")
player_re = re.compile("(.+)\|")
event_re = re.compile("<a href=[\"']/b/\d+\?m=\d[\"']>(.+ - .+ \[.+\])</a>")  # noqa
acc_re = re.compile("(\d+(?:[,.]\d*)?)%")

# Game stuff
std, taiko, ctb, mania = range(0, 4)
mode2str = {std: "Standard", taiko: "Taiko", ctb: "CTB", mania: "Mania"}
mode2osuapi = {
    std: osuapi.OsuMode.osu, taiko: osuapi.OsuMode.taiko,
    ctb: osuapi.OsuMode.ctb, mania: osuapi.OsuMode.mania,
}
mods2int = {
    "": 1 >> 1,
    "NF": 1 << 0,
    "EZ": 1 << 1,
    "TD": 1 << 2,
    "HD": 1 << 3,
    "HR": 1 << 4,
    "SD": 1 << 5,
    "DT": 1 << 6,
    "RX": 1 << 7,
    "HT": 1 << 8,
    "NC": 1 << 6 | 1 << 9,  # DT is always set along with NC.
    "FL": 1 << 10,
    "AT": 1 << 11,
    "SO": 1 << 12,
    "AP": 1 << 13,
    "PF": 1 << 5 | 1 << 14,  # SD is always set along with PF.
    "V2": 1 << 29,
}
int2mods = {v: k for k, v in mods2int.items()}
mod_order = [
    "EZ", "HD", "HT", "DT", "NC", "HR", "FL", "NF",
    "SD", "PF", "RX", "AP", "SO", "AT", "V2", "TD",
]

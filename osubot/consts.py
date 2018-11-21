import boto3
import os
import osuapi
import re
import requests_cache

# Web stuff
sess = requests_cache.CachedSession(
    backend="memory",
    expire_after=300,  # 5 minutes.
)
osu_key = os.environ["OSU_API_KEY"]
osu_api = osuapi.OsuApi(osu_key, connector=osuapi.ReqConnector(sess=sess))
osusearch_url = "https://osusearch.com/api/search"
osusearch_key = os.environ["OSUSEARCH_API_KEY"]
tillerino_key = os.environ["TILLERINO_API_KEY"]
osu_url = "https://osu.ppy.sh"
old_url = "https://old.ppy.sh"
s3_bucket = boto3.resource("s3").Bucket("osu-bot")

# Reddit stuff
reddit_user = os.environ.get("REDDIT_USER", "osu-bot")
reddit_password = os.environ["REDDIT_PASSWORD"]
reddit_client_id = os.environ["REDDIT_CLIENT_ID"]
reddit_client_secret = os.environ["REDDIT_CLIENT_SECRET"]

# Regex stuff
title_re = re.compile(".+[\|丨].+-.+\[.+\]")
map_re = re.compile(".+[\|丨](.+-.+\[.+\])")
map_pieces_re = re.compile("(.+) - (.+?)\[(.+)\]")
map_double_brackets_re = re.compile("(.+) - (.+?\[.+?\]) \[(.+)\]")
player_re = re.compile("(.+)[\|丨].+-.+\[.+\]")
event_re = re.compile("<a href=[\"']/b/\d+\?m=\d[\"']>(.+ - .+ \[.+\])</a> \((.+)\)")  # noqa
acc_re = re.compile("(\d{1,3}(?:[\.,]\d+)?)%")
tail_re = re.compile(".+[\|丨].+-.+\[.+\](.+)")
scorev2_re = re.compile("SV2|SCOREV2")
paren_re = re.compile("\((.+?)\)")
bracket_re = re.compile("\[(.+?)\]")
mapper_id_re = re.compile("Creator:</td><td class=[\"']colour[\"']><a href=[\"']/u/(\d+)")  # noqa
old_username_re = re.compile("<div class=[\"']profile-username[\"']\s+title=[\"']Previously known as (.+?)[\"']>")  # noqa
combo_re = re.compile("Max Combo</strong></td><td ?>([0-9]+)</td>")
misses_re = re.compile("<strong>Misses</strong></td><td ?>([0-9]+)</td>")
mania_misses_re = re.compile("<strong>100 / 50 / Misses</strong></td><td ?>\d+ / \d+ / ([0-9]+)</td>")  # noqa
playstyle_m_re = re.compile("<div class=[\"']playstyle mouse using[\"']></div>")  # noqa
playstyle_kb_re = re.compile("<div class=[\"']playstyle keyboard using[\"']></div>")  # noqa
playstyle_tb_re = re.compile("<div class=[\"']playstyle tablet using[\"']></div>")  # noqa
playstyle_td_re = re.compile("<div class=[\"']playstyle touch using[\"']></div>")  # noqa
osu_file_begin_re = re.compile("\A.*osu file format")

# Game stuff
std, taiko, ctb, mania = range(0, 4)
mode2str = {
    std: "osu!standard",
    taiko: "osu!taiko",
    ctb: "osu!catch",
    mania: "osu!mania",
}
int2osuapimode = {
    std: osuapi.OsuMode.osu,
    taiko: osuapi.OsuMode.taiko,
    ctb: osuapi.OsuMode.ctb,
    mania: osuapi.OsuMode.mania,
}
eventstr2mode = {
    "osu!": std,
    "Taiko": taiko,
    "Catch the Beat": ctb,
    "osu!mania": mania,
}
mode_annots = {
    "STANDARD": std,
    "STD": std,
    "OSU!": std,
    "O!STD": std,
    "OSU!STD": std,
    "OSU!STANDARD": std,
    "TAIKO": taiko,
    "OSU!TAIKO": taiko,
    "O!TAIKO": taiko,
    "CTB": ctb,
    "O!CATCH": ctb,
    "OSU!CATCH": ctb,
    "CATCH": ctb,
    "OSU!CTB": ctb,
    "O!CTB": ctb,
    "MANIA": mania,
    "O!MANIA": mania,
    "OSU!MANIA": mania,
    "OSU!M": mania,
    "O!M": mania,
}
int2status = {
    -2: "Unranked",
    -1: "Unranked",
    0: "Unranked",
    1: "Ranked",
    2: "Ranked",
    3: "Qualified",
    4: "Loved",
}
status2str = {v: k for k, v in int2status.items()}
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
    # TODO: Unranked Mania mods, maybe.
}
int2mods = {v: k for k, v in mods2int.items()}
nomod = mods2int[""]
mod_order = [
    "EZ", "HD", "HT", "DT", "NC", "HR", "FL", "NF",
    "SD", "PF", "RX", "AP", "SO", "AT", "V2", "TD",
]
ignore_mods = [mods2int[m] for m in ["SD", "PF", "RX", "AT", "AP", "V2"]]
samediffmods = [mods2int[m] for m in ["TD", "HD", "FL", "NF"]]

# Markdown/HTML stuff
dl = "&#x2b07;"  # Downwards arrow.
bar = "&#124;"  # Vertical bar.
spc = "&nbsp;"  # Non-breaking space.
hyp = "&#x2011;"  # Non-breaking hyphen.

# Misc stuff
promo_rate = 1/3
oppai_bin = os.environ.get("OPPAI_BIN", "oppai")
title_ignores = [
    "UNNOTICED",
    "UNNOTICED?",
    "RIPPLE",
    "GATARI",
    "UNSUBMITTED"
    "OFFLINE",
    "RESTRICTED",
    "BANNED",
    "UNRANKED",
    "LOVED",
]
me = "https://reddit.com/u/PM_ME_DOG_PICS_PLS"
repo_url = "https://github.com/christopher-dG/osu-bot"
unnoticed = "https://github.com/christopher-dG/unnoticed/wiki"
memes = [
    "pls enjoy gaem",
    "play more",
    "Ye XD",
    "imperial dead bicycle lol",
    "nice pass ecks dee",
    "kirito is legit",
    "can just shut up",
    "thank mr monstrata",
    "fc cry thunder and say that me again",
    "omg kappadar big fan",
    "reese get the camera",
    "cookiezi hdhr when",
    "hello there",
    "rrtyui :(",
    "0 pp if unranked",
    "these movements are from an algorithm designed in java",
]

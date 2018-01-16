import editdistance
import requests
import sys
import traceback

from . import consts


def map_str(beatmap):
    """Format a beatmap into a string."""
    if not beatmap:
        return None
    return "%s - %s [%s]" % (beatmap.artist, beatmap.title, beatmap.version)


def escape(s):
    """Escape Markdown formatting."""
    tb = str.maketrans({"^": "\^", "*": "\*", "_": "\_", "~": "\~", "<": "\<"})
    return s.translate(tb)


def combine_mods(mods):
    """Convert a mod integer to a mod string."""
    mods_a = []
    for k, v in consts.mods2int.items():
        if v & mods == v:
            mods_a.append(k)

    ordered_mods = list(filter(lambda m: m in mods_a, consts.mod_order))
    "NC" in ordered_mods and ordered_mods.remove("DT")
    "PF" in ordered_mods and ordered_mods.remove("SD")

    return "+%s" % "".join(ordered_mods) if ordered_mods else ""


def accuracy(s, mode):
    """Calculate accuracy for a score s as a float from 0-100."""
    if mode == consts.std:
        return 100 * (s.count300 + s.count100/3 + s.count50/6) / \
            (s.count300 + s.count100 + s.count50 + s.countmiss)
    if mode == consts.taiko:
        return 100 * (s.count300 + s.count100/2) / \
            (s.count300 + s.count100 + s.countmiss)
    if mode == consts.ctb:
        return 100 * (s.count300 + s.count100 + s.count50) / \
            (s.count300 + s.count100 + s.count50 + s.countkatu + s.countmiss)
    if mode == consts.mania:
        x = s.countgeki + s.count300 + 2*s.countkatu/3 + s.count100/3 + s.count50/6  # noqa
        y = s.countgeki + s.count300 + s.countkatu + s.count100 + s.count50 + s.countmiss  # noqa
        return 100 * x / y


def s_to_ts(secs):
    """Convert s seconds into a timestamp."""
    hrs = secs // 3600
    mins = (secs - hrs * 3600) // 60
    secs = secs - hrs * 3600 - mins * 60
    ts = "%02d:%02d:%02d" % (hrs, mins, secs)
    return ts if hrs else ts[3:]


def round_to_str(n, p, force=False):
    """Round n to p digits, or less if force is not set. Returns a string."""
    if p == 0:
        return str(round(n))
    if n == int(n) and not force:
        return str(int(n))
    if force:
        assert type(p) == int
        return eval("'%%.0%df' %% n" % p)
    return str(round(n, p))


def nonbreaking(s):
    """Return a visually identical version of s that does not break lines."""
    return s.replace(" ", consts.spc).replace("-", consts.hyp)


def safe_call(f, *args, alt=None, msg=None, **kwargs):
    """Execute some function, and return alt upon failure."""
    try:
        return f(*args, **kwargs)
    except Exception as e:
        print("Function %s failed: %s" % (f.__name__, e))
        print("args: %s" % list(args))
        print("kwargs: %s" % kwargs)
        traceback.print_exc(file=sys.stdout)
        if msg:
            print(msg)
        return alt


def request(url, *args, text=True, **kwargs):
    """Wrapper around requests.get."""
    resp = safe_call(requests.get, url, *args, **kwargs)

    if not resp:
        print("Request to %s returned empty" % safe_url(url))
        return None
    if resp.status_code != 200:
        print("Request to %s returned %d" % (safe_url(url), resp.status_code))
        return None
    if not resp.text:
        print("Request to %s returned empty body" % safe_url(url))
        return None

    return resp.text if text else resp


def sep(n):
    """Format n with commas."""
    return"{:,}".format(n)


def safe_url(s):
    """Obfuscate sensitive keys in a string."""
    return s.replace(consts.osu_key, "###").replace(consts.osusearch_key, "###")  # noqa


def compare(x, y):
    """Leniently compare two strings."""
    x = x.replace(" ", "").replace("&quot;", "\"").replace("&amp;", "&")
    y = y.replace(" ", "").replace("&quot;", "\"").replace("&amp;", "&")
    return editdistance.eval(x.upper(), y.upper()) <= 2


def is_ignored(mods):
    """Check whether all enabled mods are to be ignored."""
    if mods is None:
        return True
    nonignores = set(consts.int2mods.keys()) - set(consts.ignore_mods)
    return not any(m & mods for m in nonignores)


def changes_diff(mods):
    """Check whether any enabled mods change difficulty values."""
    if mods is None:
        return False
    diff_changers = set(consts.int2mods.keys()) - set(consts.samediffmods)
    return any(m & mods for m in diff_changers)


def matched_bracket_contents(s):
    """Find the contents of a pair of square brackets."""
    if "[" not in s:
        return None

    s = s[(s.index("[") + 1):]
    n = 0
    for i, c in enumerate(s):
        if c == "]" and n == 0:
            return s[:i]
        elif c == "]":
            n -= 1
        elif c == "[":
            n += 1

    return None

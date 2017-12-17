cache = {"f": None, "args": None, "kwargs": None, "result": None}

from . import consts, context, markdown  # noqa


def main(title):
    """Main driver function going from submission title to posting a reply."""
    print("Post title: %s" % title)

    if not consts.title_re.match(title):
        print("Not a score post")
        return False

    ctx = context.build_ctx(title)
    print(ctx)

    if not ctx.player and not ctx.beatmap:
        print("Both player and beatmap are missing")
        return False

    reply = markdown.build_comment(ctx)
    print(reply)

    return True

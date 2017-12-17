cache = {"f": None, "args": None, "kwargs": None, "result": None}

from . import consts, context, markdown  # noqa


def main(title):
    """Main driver function going from submission title to posting a reply."""
    print("Post title: %s" % title)

    if not consts.title_re.match(title):
        print("Not a score post")
        return None

    ctx = context.build_ctx(title)

    if not ctx.player and not ctx.beatmap:
        print("Both player and beatmap are missing")
        return None

    return ctx, markdown.build_comment(ctx)

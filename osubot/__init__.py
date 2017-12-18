cache = {"f": None, "args": None, "kwargs": None, "result": None}

from . import consts, context, markdown  # noqa


def scorepost(title):
    """Generate a reply to a score post from a title."""
    print("Post title: %s" % title)

    if not consts.title_re.match(title):
        print("Not a score post")
        return None

    ctx = context.from_score_post(title)

    if not ctx.player and not ctx.beatmap:
        print("Both player and beatmap are missing")
        return None

    return ctx, markdown.build_comment(ctx)

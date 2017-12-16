from . import consts, context, markdown


def main(title):
    """Main driver function going from submission title to posting a reply."""
    print("Post title: %s" % title)

    if not consts.title_re.match(title):
        print("Not a score post")
        return False

    ctx = context.build_ctx(title)
    print(ctx)
    reply = markdown.build_comment(ctx)
    print(reply)

    return True

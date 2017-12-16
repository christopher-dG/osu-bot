from . import consts, context


def main(title):
    """Main driver function going from submission title to posting a reply."""
    print("Post title: %s" % title)

    if not consts.title_re.match(title):
        print("Not a score post")
        return False

    ctx = context.build_ctx(title)
    print(ctx)

    return True

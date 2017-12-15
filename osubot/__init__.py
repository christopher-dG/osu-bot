import re

title_regex = "(.+)\|(.+ - .+\[.+\])"


def main(title):
    """Main driver function going from submission title to posting a reply."""
    print("Post title: %s" % title)

    if not re.match(title_regex, title):
        print("Not a score post")
        return False

    return True

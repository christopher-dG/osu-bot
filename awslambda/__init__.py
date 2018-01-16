import json
import os
import praw
import shutil
import stat
import time

testrun = True
post_id = None
post_title = None
start = None


def initialize(event, post):
    """Set some internal variables."""
    global start
    start = time.time()

    global testrun
    testrun = os.environ.get("LAMBDA_TEST", "").lower() != "false" or (
        event["queryStringParameters"].get("test") == "true")
    if testrun:
        print("=== BEGIN TEST RUN ===")

    try:
        global post_title
        post_title = post.title
    except Exception as e:
        print("No post title: %s" % e)
        return False
    global post_id
    post_id = post.id

    return True


def finish(status=200, error=None, **kwargs):
    """Return the API response."""
    if error:
        print(error)
    resp = {
        "isBase64Encoded": False,
        "headers": {},
        "statusCode": status,
        "body": {
            "test": testrun,
            "postID": post_id,
            "postTitle": post_title,
            "error": error,
            **kwargs,
        },
    }
    if start is not None:
        resp["body"]["time"] = time.time() - start
    print(json.dumps(resp, indent=4))
    resp["body"] = json.dumps(resp["body"])
    if testrun:
        print("=== END TEST RUN ===")
    return resp


def chmod(src, dest):
    """Move an executable to where it can be ran and give it permissions."""
    if not os.path.isfile(src):
        print("%s does not exist" % src)
        return None

    if not dest.startswith("/tmp/"):
        dest = os.path.normpath("/tmp/%s" % dest)

    try:
        shutil.copyfile(src, dest)
        os.chmod(dest, os.stat(src).st_mode | stat.S_IEXEC)
    except Exception as e:
        print("chmod failed: %s" % e)
        return False

    return True


def reddit_login(username):
    """Log into Reddit."""
    return praw.Reddit(
        client_id=os.environ["REDDIT_CLIENT_ID"],
        client_secret=os.environ["REDDIT_CLIENT_SECRET"],
        password=os.environ["REDDIT_PASSWORD"],
        user_agent=username,
        username=username,
    )


def post_has_reply(post, username):
    """Check if post has a top-level reply by username."""
    return not testrun and any(
        c.author.name == username if c.author else False
        for c in post.comments
    )


def post_reply(post, text, sticky=False):
    """
    Reply to, save, and upvote a post, and optionally sticky the comment.
    Returns None on success, the error in string form otherwise.
    """
    if testrun:
        return None

    try:
        c = post.reply(text)
        if sticky:
            c.mod.distinguish(sticky=True)
        post.save()
        post.upvote()
    except Exception as e:
        print("Reddit exception: %s" % e)
        return str(e)

    return None


def post_is_saved(post):
    """Check whether the post is saved."""
    return not testrun and post.saved


from .scorepost import scorepost  # noqa

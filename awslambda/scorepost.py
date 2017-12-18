import os
import osubot
import praw
import sys
import traceback

from . import (
    chmod,
    finish,
    initialize,
    post_has_reply,
    post_is_saved,
    post_reply,
    reddit_login,
)


def scorepost(event, _):
    p_id = event["queryStringParameters"].get("id", None)
    if p_id is None:
        return finish(status=400, error="Missing id parameter")
    print("ID: %s" % p_id)

    reddit = reddit_login(osubot.consts.reddit_user)
    post = praw.models.Submission(reddit, p_id)

    if not initialize(event, post):
        return finish(status=500, error="Initialization failed")

    try:
        if post_is_saved(post):
            return finish(error="Post is already saved")
    except Exception as e:  # Post likely doesn't exist.
        return finish(status=400, error=str(e))

    chmod("oppai", os.environ.get("OPPAI_BIN", "/tmp/oppai"))

    if not osubot.consts.title_re.match(post.title):
        return finish(error="Not a score post")

    try:
        result = osubot.scorepost(post.title)
        if result is None:
            return finish(status=500, error="Comment generation failed")
        ctx, reply = result
    except Exception as e:
        traceback.print_exc(file=sys.stdout)
        return finish(status=500, error=str(e))

    if not reply:
        return finish(status=500, error="Reply is empty")

    if post_has_reply(post, osubot.consts.reddit_user):
        return finish(error="Post already has a reply")

    if post_reply(post, reply, sticky=True):
        print("%s\nCommented:\n%s" % (ctx, reply))

    return finish(context=ctx.to_dict(), comment=reply)

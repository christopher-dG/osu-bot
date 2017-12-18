import os
import osubot
import praw
import sys
import time
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
    start = time.time()
    p_id = event["queryStringParameters"].get("id", None)
    if p_id is None:
        return finish(status=400, error="Missing id parameter", time=start)
    print("ID: %s" % p_id)

    reddit = reddit_login(osubot.consts.reddit_user)
    post = praw.models.Submission(reddit, p_id)

    if not initialize(event, post):
        return finish(status=500, error="Initialization failed", time=start)

    try:
        if post_is_saved(post):
            return finish(error="Post is already saved", time=start)
    except Exception as e:  # Post likely doesn't exist.
        return finish(status=400, error=str(e), time=start)

    chmod("oppai", os.environ.get("OPPAI_BIN", "/tmp/oppai"))

    if not osubot.consts.title_re.match(post.title):
        return finish(error="Not a score post", time=start)

    try:
        result = osubot.scorepost(post.title)
        if result is None:
            return finish(
                status=500,
                error="Comment generation failed",
                time=start,
            )
        ctx, reply = result
    except Exception as e:
        traceback.print_exc(file=sys.stdout)
        return finish(status=500, error=str(e), time=start)

    if not reply:
        return finish(status=500, error="Reply is empty", time=start)

    if post_has_reply(post, osubot.consts.reddit_user):
        return finish(error="Post already has a reply", time=start)

    err = post_reply(post, reply, sticky=True)
    if err:
        return finish(
            status=500,
            context=ctx.to_dict(),
            comment=reply,
            error=err,
            time=start,
        )

    print("%s\nCommented:\n%s" % (ctx, reply))
    return finish(context=ctx.to_dict(), comment=reply, time=start)

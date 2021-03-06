import json
import os
import sys
import traceback

import praw

from . import consts, scorepost

from flask import Flask, request

app = Flask(__name__)

testrun = False
gameplay_flair = ["5d2f4278-89df-11e4-aa8d-22000bc18bb2", "Gameplay"]


@app.route("/scorepost", methods=["POST"])
def handler():
    p_id = request.args.get("id")
    if p_id is None:
        return finish(status=400, error="Missing id parameter")
    print("ID: %s" % p_id)
    global testrun
    testrun = request.args.get("test") == "true"
    print(testrun)
    reddit = reddit_login(consts.reddit_user)
    post = praw.models.Submission(reddit, p_id)
    try:
        if post_is_saved(post):
            return finish(error="Post is already saved")
    except Exception as e:  # Post likely doesn't exist.
        return finish(status=400, error=str(e))
    if not consts.title_re.match(post.title):
        return finish(error="Not a score post")
    try:
        result = scorepost(post.title)
        if result is None:
            return finish(status=500, error="Comment generation failed")
        ctx, reply = result
    except Exception as e:
        traceback.print_exc(file=sys.stdout)
        return finish(status=500, error=str(e))
    if not reply:
        return finish(status=500, error="Reply is empty")
    if post_has_reply(post, consts.reddit_user):
        return finish(error="Post already has a reply")
    ctx_d = ctx.to_dict()
    err = post_reply(post, reply, sticky=True, flair=gameplay_flair)
    if err:
        return finish(
            status=500,
            context=ctx_d,
            comment=reply,
            error=err,
        )
    print("%s\nCommented:\n%s" % (ctx, reply))
    return finish(context=ctx_d, comment=reply)


def finish(status=200, error=None, **kwargs):
    if error:
        print(error)
    return {"error": error, **kwargs}, status


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


def post_reply(post, text, sticky=False, flair=[]):
    """
    Reply to, save, and upvote a post, optionally flair it,
    and optionally sticky the comment.
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
        if flair:
            post.flair.select(*flair)
    except Exception as e:
        print("Reddit exception: %s" % e)
        return str(e)

    return None


def post_is_saved(post):
    """Check whether the post is saved."""
    return not testrun and post.saved

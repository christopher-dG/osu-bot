import json
import os
import osubot
import praw
import shutil
import stat

body = {"error": None, "comment": None, "context": None}
resp = {
    "isBase64Encoded": False,
    "statusCode": 500,
    "headers": {},
    "body": json.dumps(body),
}
testrun = os.environ.get("LAMBDA_TEST", "").lower() != "false"


def handler(event, _):
    if testrun:
        print("=== TEST RUN ===")
    p_id = event["queryStringParameters"].get("id", None)
    if p_id is None:
        err = "Missing id parameter"
        print(err)
        resp["statusCode"] = 400
        body["error"] = err
        resp["body"] = json.dumps(body)
        return resp
    print("ID: %s" % p_id)

    rdt = praw.Reddit(
        client_id=os.environ["REDDIT_CLIENT_ID"],
        client_secret=os.environ["REDDIT_CLIENT_SECRET"],
        password=os.environ["REDDIT_PASSWORD"],
        user_agent=osubot.consts.reddit_user,
        username=osubot.consts.reddit_user,
    )
    post = praw.models.Submission(rdt, p_id)
    try:
        if not testrun and post.saved:
            print("Post is already saved")
            return resp
    except Exception as e:  # Quite likely doesn't exist.
        print(e)
        resp["statusCode"] = 400
        body["error"] = str(e)
        resp["body"] = json.dumps(body)
        return resp

    oppai = osubot.consts.oppai_bin
    shutil.copyfile("oppai", oppai)
    os.chmod(oppai, os.stat(oppai).st_mode | stat.S_IEXEC)

    try:
        result = osubot.main(post.title)
        if result is None:
            err = "Comment generation failed"
            print(err)
            resp["statusCode"] = 500
            body["error"] = err
            resp["body"] = json.dumps(body)
            return resp
        ctx, reply = result
    except Exception as e:
        print("Exception raised while generating reply: %s" % e)
        resp["statusCode"] = 500
        body["error"] = str(e)
        resp["body"] = json.dumps(e)
        return resp

    if not reply:
        err = "Reply is empty"
        print(err)
        resp["statusCode"] = 500
        body["error"] = err
        resp["body"] = json.dumps(body)
        return resp

    if not testrun and any(
        c.author.name == osubot.consts.reddit_user if c.author else False
        for c in post.comments,
    ):
        print("Post already has a reply")
        try:
            post.save()
            post.upvote()
        except:
            pass
    elif not testrun:
        c = post.reply(reply)
        c.mod.distinguish(sticky=True)
        post.save()
        post.upvote()

    body["context"] = ctx.to_dict()
    body["comment"] = reply
    resp["body"] = json.dumps(body)

    print("%s\nCommented:\n%s" % (ctx, reply))

    if testrun:
        print("=== TEST RUN ===")

    return resp

#!/usr/bin/env python3

import json
import logging
import os
import praw
import re
import requests
import sys
import time

auto = "--auto" in sys.argv
nofilter = "--no-filter" in sys.argv
score_re = re.compile(".+\|.+-.+\[.+\]")
user = "osu-bot"
sub = os.environ.get("OSU_BOT_SUB", "osugame")
api = "https://2s5lll4kz9.execute-api.us-east-1.amazonaws.com/scorepost/proxy"
ids = []
logger = logging.getLogger()
logging.basicConfig(format="%(asctime)s: %(message)s", level=logging.INFO)


def monitor():
    reddit = praw.Reddit(
        client_id=os.environ["REDDIT_CLIENT_ID"],
        client_secret=os.environ["REDDIT_CLIENT_SECRET"],
        password=os.environ["REDDIT_PASSWORD"],
        user_agent=user,
        username=user,
    )
    subreddit = reddit.subreddit(sub)

    while True:
        for post in subreddit.new():
            if post.id in ids:
                continue
            if not nofilter and not score_re.match(post.title):
                continue

            if post_api(post.id):
                ids.append(post.id)

            print("\n====================================\n")
            if not auto:
                input("Press enter to proceed to the next post: ")
                print()

        logger.info("Waiting for posts")
        time.sleep(10)


def post_api(p_id):
    url = "%s?id=%s" % (api, p_id)
    logger.info("Posting to %s" % url)
    resp = requests.post(url)
    d = resp.json()
    comment = d.pop("comment", None)
    if comment:
        d["comment"] = "<omitted>"
    print("%d: %s" % (resp.status_code, json.dumps(d, indent=4)))
    if comment:
        print("Comment:\n%s" % comment)
    return resp.status_code == 200


if __name__ == "__main__":
    logger.info("auto = %s" % auto)
    logger.info("nofilter = %s" % nofilter)

    while True:
        try:
            monitor()
        except KeyboardInterrupt:
            print("\nExiting")
            break
        except Exception as e:
            logger.info("Exception: %s" % e)

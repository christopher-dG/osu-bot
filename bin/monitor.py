#!/usr/bin/env python3

import json
import logging
import os
import praw
import re
import requests
import sys
from dotenv import load_dotenv

load_dotenv()

sys.stdout = sys.stderr
auto = "--auto" in sys.argv
nofilter = "--no-filter" in sys.argv
test = "--test" in sys.argv
score_re = re.compile(".+[\|丨].+-.+\[.+\]")
user = os.environ.get("OSU_BOT_USER", "osu-bot")
sub = os.environ.get("OSU_BOT_SUB", "osugame")
api = f'{os.environ.get("API_HOST")}:{os.environ.get("FLASK_RUN_PORT", 5000)}/scorepost'
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

    for post in subreddit.stream.submissions():
        if not nofilter and not score_re.match(post.title):
            logger.info("Skipping '%s' - '%s'" % (post.id, post.title))
            continue
        if not test and post.saved:
            logger.info("Skipping '%s' - '%s'" % (post.id, post.title))
            continue

        post_api(post.id)

        print("\n====================================\n")
        if not auto:
            input("Press enter to proceed to the next post: ")
            print()


def post_api(p_id):
    url = "%s?id=%s" % (api, p_id)
    if test:
        url += "&test=true"
    logger.info("Posting to %s" % url)
    resp = requests.post(url)
    # data = resp.json()
    # print(data)
    logger.info(f"Post success, got status {resp.status_code}")
    return resp.status_code == 200


if __name__ == "__main__":
    if "REDDIT_PASSWORD" not in os.environ:
        print("Missing Reddit environment variables")
        exit(1)

    logger.info("auto = %s" % auto)
    logger.info("nofilter = %s" % nofilter)
    logger.info("test = %s" % test)

    while True:
        try:
            monitor()
        except KeyboardInterrupt:
            print("\nExiting")
            break
        except Exception as e:
            logger.info("Exception: %s" % e)

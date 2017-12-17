#!/usr/bin/env python3

import datetime
import os
import praw
import re
import requests
import time

user = "osu-bot"
sub = os.environ.get("OSU_BOT_SUB", "osugame")
score_re = re.compile(".+\|.+-.+\[.+\]")
api = "https://2s5lll4kz9.execute-api.us-east-1.amazonaws.com/scorepost/proxy"
reddit = praw.Reddit(
    client_id=os.environ["REDDIT_CLIENT_ID"],
    client_secret=os.environ["REDDIT_CLIENT_SECRET"],
    password=os.environ["REDDIT_PASSWORD"],
    user_agent=user,
    username=user,
)
subreddit = reddit.subreddit(sub)
ids = []

while True:
    print(datetime.datetime.now())
    try:
        for post in list(filter(lambda i: i not in ids, set(subreddit.new()))):
            if not score_re.match(post.title):
                print("'%s' is not a score post" % post.title)
                ids.append(post.id)
                continue
            if post.saved:
                print("'%s' is already saved" % post.title)
                continue
            if any(c.author.name == user for c in post.comments):
                print("'%s' already has a reply" % post.title)
                continue

            print("Score post: %s" % post.title)
            url = "%s?id=%s" % (api, post.id)
            print("Posting to %s" % url)
            resp = requests.post(url)
            print(resp)
            ids.append(post.id)
    except Exception as e:
        print("Exception: %s" % e)
    time.sleep(10)
    ids = list(set(ids))

#!/usr/bin/env python3

import logging
import os
import praw
import re
import sys
import time

sys.stdout = sys.stderr
test = "--test" in sys.argv
user = os.environ.get("OSU_BOT_USER", "osu-bot")
sub = os.environ.get("OSU_BOT_SUB", "osugame")
yt_re = re.compile("https?://(?:www\.)?(?:youtu\.be/|youtube\.com/watch\?v=)([\w-]+)")  # noqa
video_header = "YouTube links:"
time_threshold = 60  # One minute.
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

    for comment in subreddit.stream.comments():
        if not comment.is_root:
            continue
        match = yt_re.search(comment.body)
        if not match:
            continue

        bot_comment = find_bot_comment(comment)
        if bot_comment is None:
            continue
        edit_bot_comment(bot_comment, match.group(1))


def find_bot_comment(other):
    """Look for a comment by the bot on the post that other replied to."""
    submission = other.submission

    # Sometimes video comments get made before the bot comment is posted.
    # This could be made a bit less conservative by comparing the current time
    # rather than the post creation time, but the Reddit timestamps seem off
    # relative to normal UTC (but at least they're consistent with each other).
    if other.created_utc - submission.created_utc < time_threshold:
        time.sleep(time_threshold)

    logger.info("Searching post %s" % submission.id)

    for comment in submission.comments:
        if comment.author.name == user and comment.is_root:
            logger.info("Found comment:\n%s" % comment.body)
            return comment

    logger.info("No bot comment found on post %s" % submission.id)
    return None


def edit_bot_comment(comment, yt_id):
    """Add a new video link to a bot comment."""
    if yt_id in comment.body:
        logger.info("Video is already linked")
        return False
    lines = comment.body.split("\n")

    for idx, line in enumerate(lines):
        if line.startswith(video_header):
            break
        if line == "***":
            lines.insert(idx, video_header)
            lines.insert(idx + 1, "")
            break
    else:
        logger.info("Couldn't find a place to insert video link.")
        return False

    n = len(lines[idx].split()) - len(video_header.split()) + 1
    lines[idx] += " [[%d]](https://youtu.be/%s)" % (n, yt_id)
    body = "\n".join(lines)

    if not test:
        comment.edit(body)

    logger.info("New comment contents:\n%s" % body)
    return True


if __name__ == "__main__":
    if "REDDIT_PASSWORD" not in os.environ:
        print("Missing Reddit environment variables")
        exit(1)

    logger.info("test = %s" % test)

    while True:
        try:
            monitor()
        except KeyboardInterrupt:
            print("\nExiting")
            break
        except Exception as e:
            logger.info("Exception: %s" % e)

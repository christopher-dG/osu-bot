#!/usr/bin/env python3

import logging
import os
import praw
import re
import requests
import sys
import time

sys.stdout = sys.stderr
test = "--test" in sys.argv
user = os.environ.get("OSU_BOT_USER", "osu-bot")
sub = os.environ.get("OSU_BOT_SUB", "osugame")
yt_re = re.compile("https?://(?:www\.)?(?:youtu\.be/|youtube\.com/watch\?v=)([\w-]+)")  # noqa
yt_key = os.environ.get("YOUTUBE_KEY")
video_header = "YouTube links:"
time_threshold = 30  # Seconds.
yt_api = "https://www.googleapis.com/youtube/v3/videos"
logger = logging.getLogger()
logging.basicConfig(format="%(asctime)s: %(message)s", level=logging.INFO)

reddit = None


def reddit_login():
    """Log in to Reddit."""
    global reddit
    reddit = praw.Reddit(
        client_id=os.environ["REDDIT_CLIENT_ID"],
        client_secret=os.environ["REDDIT_CLIENT_SECRET"],
        password=os.environ["REDDIT_PASSWORD"],
        user_agent=user,
        username=user,
    )


def process_comment(comment):
    if not comment.is_root or comment.saved:
        return

    match = yt_re.search(comment.body)
    if not match:
        return

    bot_comment = find_bot_comment(comment)
    if bot_comment is None:
        return

    if edit_bot_comment(bot_comment, match.group(1)):
        comment.save()


def process_backlog():
    """Process the 100 most recent comments."""
    for comment in reddit.subreddit(sub).comments():
        process_comment(comment)


def process_stream():
    """Process comments as they arrive."""
    for comment in reddit.subreddit(sub).stream.comments():
        process_comment(comment)


def find_bot_comment(other):
    """Look for a comment by the bot on the post that other replied to."""
    submission = other.submission

    # Sometimes video comments get made before the bot comment is posted.
    # This could be made a bit less conservative by comparing the current time
    # rather than the post creation time, but the Reddit timestamps seem off
    # relative to normal UTC (but at least they're consistent with each other).
    if other.created_utc - submission.created_utc < time_threshold:
        logger.info("Sleeping")
        time.sleep(time_threshold)
        # To refresh the comments, we're stuck using this private method
        # or creating a new instance.
        submission._fetch()

    logger.info("Searching post %s" % submission.id)

    for comment in submission.comments:
        if comment.author.name == user and comment.is_root:
            logger.info("Found comment:\n%s\n" % comment.body)
            return comment

    logger.info("No bot comment found on post %s" % submission.id)
    return None


def get_youtube_data(yt_id):
    """Get the title and creator of a YouTube video."""
    params = {"id": yt_id, "part": "snippet", "key": yt_key}
    try:
        resp = requests.get(yt_api, params=params)
    except Exception as e:
        logger.info("Request exception: %s" % e)
        return None, None

    if resp.status_code != 200:
        logger.info("YouTube API returned %d" % resp.status_code)
        return None, None

    try:
        data = resp.json()["items"][0]["snippet"]
    except Exception as e:
        logger.info("JSON error: %s" % e)
        return None, None

    return data.get("title"), data.get("channelTitle")


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

    n = lines[idx].count("https://youtu.be") + 1
    url = "https://youtu.be/%s" % yt_id

    title, channel = get_youtube_data(yt_id)
    if bool(title) and bool(channel):
        url += " \"'%s' by '%s'\"" % (title, channel)

    lines[idx] += " [[%d]](%s)" % (n, url)
    body = "\n".join(lines)

    if not test:
        comment.edit(body)

    logger.info("New comment contents:\n%s\n" % body)
    return True


if __name__ == "__main__":
    if "REDDIT_PASSWORD" not in os.environ:
        print("Missing Reddit environment variables")
        exit(1)
    if "YOUTUBE_KEY" not in os.environ:
        print("Missing YouTube environment variables")
        exit(1)

    reddit_login()
    logger.info("test = %s" % test)

    try:
        process_backlog()
    except Exception as e:
        print("Backlog exception: %s" % e)

    while True:
        try:
            process_stream()
        except KeyboardInterrupt:
            print("\nExiting")
            break
        except Exception as e:
            logger.info("Stream exception: %s" % e)

import os

from typing import Iterator, Optional

from praw import Reddit
from praw.models import Comment, Submission

from .globals import logger

_reddit = Reddit(
    client_id=os.getenv("REDDIT_CLIENT_ID", ""),
    client_secret=os.getenv("REDDIT_CLIENT_SECRET", ""),
    username=os.getenv("REDDIT_USERNAME", ""),
    password=os.getenv("REDDIT_PASSWORD", ""),
    user_agent=os.getenv("REDDIT_USER_AGENT", ""),
)
_sub = _reddit.subreddit(os.getenv("REDDIT_SUBREDDIT", ""))


def get_post(id: str) -> Submission:
    """Get a Reddit post."""
    logger.debug(f"Getting post: {id}")
    return _reddit.submission(id)


def get_comment(id: str) -> Comment:
    """Get a Reddit comment."""
    logger.debug(f"Getting comment: {id}")
    return _reddit.comment(id)


def get_posts(anchor: Optional[str]) -> Iterator[Submission]:
    """Get new posts."""
    logger.debug(f"Listing posts, starting at {anchor}")
    yield from _get_listing(_sub.new, anchor)


def get_comments(anchor: Optional[str]) -> Iterator[Comment]:
    logger.debug(f"Listing comments, starting at {anchor}")
    yield from _get_listing(_sub.comments, anchor)


def _get_listing(listing, anchor: Optional[str]) -> Iterator:
    params = {}
    if anchor is not None:
        params["before"] = anchor
    yield from listing(limit=None, params=params)

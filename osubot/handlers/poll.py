import re

from typing import Callable, Iterator, Optional, TypeVar

from praw.models import Comment, Submission

from .. import aws, reddit

_anchor = "reddit_anchor"
_re_post = re.compile(r".+\|.+-.+\[.+\]")
T = TypeVar("T", Comment, Submission)


def handler(_event={}, _context=None) -> None:
    # TODO: Multiplex the streams somehow, e.g. https://redd.it/7jng5a.
    _poll_posts()
    _poll_comments()


def _make_poller(
    listing: Callable[[Optional[str]], Iterator[T]], key: str
) -> Callable[[], None]:
    """Return a function that polls a Reddit listing."""

    def poller() -> None:
        anchor = _get_anchor(key)
        things = list(listing(anchor))
        for thing in things:
            if _should_process(thing):
                aws.lambda_invoke_function(key, thing.id)
        if things:
            anchor = things[0].id
            if anchor:
                _set_anchor(key, anchor)

    return poller


_poll_posts = _make_poller(reddit.get_posts, "post")
_poll_comments = _make_poller(reddit.get_comments, "comment")


def _should_process(thing: T) -> bool:
    """Determine whether a post or comment should be processed."""
    if thing.saved:
        return False
    if isinstance(thing, Comment):
        return _is_mention(thing) or _is_video_link(thing)
    if isinstance(thing, Submission):
        return _is_score_post(thing)
    return False


def _is_mention(comment: Comment) -> bool:
    """Determine whether or not a comment is a username mention."""
    return hasattr(comment, "subject") and comment.subject == "username mention"


def _is_video_link(comment: Comment) -> bool:
    """Determine whether or not a comment is a video link."""
    return "youtube.com" in comment.body or "youtu.be" in comment.body


def _is_score_post(post: Submission) -> bool:
    """Determine whether or not a post is a score post."""
    return bool(_re_post.search(post.title))


def _get_anchor(key: str) -> Optional[str]:
    """Get a Reddit anchor."""
    item = aws.ddb_get_item(_anchor)
    if item is None:
        return None
    # TO#O: can probably remove str conversion when DDB types are better.
    return str(item[key])


def _set_anchor(key: str, anchor: str) -> None:
    """Set a Reddit anchor."""
    aws.ddb_update_item(_anchor, {key: anchor})

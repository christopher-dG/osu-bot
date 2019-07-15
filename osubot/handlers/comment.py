from .. import reddit


def handler(id: str, _context=None) -> None:
    comment = reddit.get_comment(id)

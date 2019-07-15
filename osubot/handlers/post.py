from .. import reddit


def handler(id: str, _context=None) -> None:
    post = reddit.get_post(id)

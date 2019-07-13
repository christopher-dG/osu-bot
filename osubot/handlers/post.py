import os


def handler(event: dict, _context=None) -> None:
    print(os.system("oppai -v"))

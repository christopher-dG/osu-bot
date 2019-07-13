from osubot import markdown


def test_bold():
    assert markdown.bold("foo") == "**foo**"
    assert markdown.bold("f**o**o") == "**f\\*\\*o\\*\\*o**"


def test_escape():
    pass


def test_link():
    pass


def test_nonbreaking():
    pass


def test_superscript():
    pass


def test_table():
    pass

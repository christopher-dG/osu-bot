from typing import List

_bar = "&#124;"

hrule = "\n---\n"
hyphen = "&#x2011;"
space = "&nbsp;"


def bold(s: str) -> str:
    """Format a string as bold."""
    escaped = s.replace("**", "\\*\\*")
    return f"**{escaped}**"


def escape(s: str) -> str:
    """Escape any Markdown formatting."""
    pass  # TODO


def link(text: str, url: str) -> str:
    """Format a link."""
    return f"[{text}]({url})"


def nonbreaking(s: str) -> str:
    """Force a string onto a single line."""
    return s.replace("-", hyphen).replace(" ", space)


def superscript(s: str) -> str:
    """Format a string as superscript."""
    return f"^({s})"


def table(rows: List[List[str]]) -> str:
    """Create a Markdown table."""
    lines = [" | ".join(s.replace("|", _bar) for s in row) for row in rows]
    lines.insert(1, " | ".join(":-:" for _ in range(len(rows[0]))))
    return "\n".join(lines)

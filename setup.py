from setuptools import setup

setup(
    name="osubot",
    description="/r/osugame's benevolent robot overlord",
    author="Chris de Graaf",
    author_email="chrisadegraaf@gmail.com",
    url="https://github.com/christopher-dG/osu-bot-serverless",
    license="MIT",
    version="0.0.0",
    packages=["osubot"],
    install_requires=[
        "markdown-strings",
        "osuapi",
        "praw",
        "requests",
    ],
    zip_safe=True,
)

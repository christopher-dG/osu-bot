#!/usr/bin/env sh

set -e
python3 -m pip install -r osubot/requirements.txt -t build --upgrade
cp -r handler.py osubot build
cd build
zip -r ../pkg.zip *

#!/usr/bin/env sh

set -e
cd $(dirname $(dirname "$0"))
python3 -m pip install -r requirements.txt -Ut build
cp -r handler.py osubot build
cd build
aws s3 cp s3://osu-bot-serverless/bin/oppai ./oppai
zip -r ../pkg.zip *

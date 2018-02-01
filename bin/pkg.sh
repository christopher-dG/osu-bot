#!/usr/bin/env sh

set -e
cd $(dirname $(dirname "$0"))
sed -i 's/boto3/#boto3/' requirements.txt  # boto3 comes preinstalled in Lambda.
python3 -m pip install -r requirements.txt -Ut build
sed -i 's/#boto3/boto3/' requirements.txt
cp -r awslambda osubot build
cd build
aws s3 cp s3://osu-bot-serverless/bin/oppai ./oppai
zip -r ../pkg.zip *

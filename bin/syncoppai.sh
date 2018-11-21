#!/usr/bin/env sh

set -e
dir=$(dirname "$0")
[ -d $dir/oppai-ng ] || git clone https://github.com/Francesco149/oppai-ng $dir/oppai-ng
cd $dir/oppai-ng
git fetch origin
git reset --hard origin/master
./build
aws s3 cp oppai s3://osu-bot/bin/oppai

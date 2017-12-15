#!/usr/bin/env sh

set -e

[ "$(uname)" = "Linux" ] || [ "$1" = "nooppai" ] || (echo "Can only build on Linux; aborting" && false)

python3 -m pip install -r osubot/requirements.txt -t build --upgrade
cp -r handler.py osubot build
cd build

if [ "$1" != "nooppai" ]; then
   git clone https://github.com/Francesco149/oppai-ng
   cd oppai-ng
   ./build
   cd ..
   mkdir bin
   mv oppai-ng/oppai bin
   chmod -R 777 bin
   rm -rf oppai-ng
fi

zip -r ../pkg.zip *

#!/usr/bin/env sh

set -e

IMAGE="amazonlinux:2018.03"
OPPAI="3.2.3"

if [ "$1" = build ]; then
  yum -y update
  yum -y install gcc
  curl -L "https://github.com/Francesco149/oppai-ng/archive/$OPPAI.tar.gz" | tar zxf -
  cd "oppai-ng-$OPPAI"
  ./build
  mkdir /opt/bin
  mv oppai /opt/bin
else
  cd $(dirname "$0")/..
  mkdir -p layers/oppai
  cp "$0" layers/oppai
  docker run --rm --mount "type=bind,source=$(pwd)/layers/oppai,destination=/opt" "$IMAGE" /opt/$(basename "$0") build
fi

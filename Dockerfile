FROM python:3.6-alpine
ENV PYTHONPATH /root
ENV FLASK_APP osubot.server
ENV FLASK_RUN_HOST 0.0.0.0
ENV FLASK_RUN_PORT 5000
ENV OPPAI_VERSION 4.1.0
COPY requirements.txt /tmp/requirements.txt
RUN apk add gcc git libc-dev && \
  git clone https://github.com/Francesco149/oppai-ng /tmp/oppai && \
  cd /tmp/oppai && \
  git checkout $OPPAI_VERSION && \
  ./build && \
  install oppai /usr/bin/oppai && \
  pip install -r /tmp/requirements.txt && \
  apk del gcc git libc-dev && \
  rm -rf /tmp/oppai /tmp/requirements.txt
COPY bin /root/bin
COPY osubot /root/osubot

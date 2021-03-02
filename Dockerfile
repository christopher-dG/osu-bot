FROM python:3.6-alpine
COPY requirements.txt /tmp/requirements.txt
RUN apk add git && \
  pip install -r /tmp/requirements.txt && \
  apk del git && \
  rm /tmp/requirements.txt
COPY bin /root/bin

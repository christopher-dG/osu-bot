FROM python:3.12-alpine
ENV PYTHONPATH /root
ENV FLASK_APP osubot.server
ENV FLASK_RUN_HOST 0.0.0.0
ENV FLASK_RUN_PORT 5000
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt
COPY bin/ /root/bin
COPY osubot /root/osubot

FROM rust:1.73.0 as rosu
COPY rosu-pp-cli .
RUN cargo install --path .

FROM python:3.11-slim
ENV PYTHONPATH /root
ENV FLASK_APP osubot.server
ENV FLASK_RUN_HOST 0.0.0.0
ENV FLASK_RUN_PORT 5000
COPY requirements.txt /tmp/requirements.txt
COPY bin /root/bin
COPY osubot /root/osubot
COPY --from=rosu /usr/local/cargo/bin/rosu-pp-cli /usr/local/bin/rosu-pp-cli

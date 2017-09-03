FROM julia:0.6.0

ENV APP /root/OsuBot
ENV PKGS python3-pip hdf5-tools git unzip build-essential
ENV PYTHON /usr/bin/python3
ENV PYTHONPKGS praw

RUN mkdir -p $APP
COPY . $APP

RUN apt-get update && \
    apt-get install -y $PKGS && \
    pip3 install $PYTHONPKGS && \
    cd $APP && \
    mv oppai /usr/local/bin/ && \
    julia -e 'Pkg.clone(pwd()); cp("config.yml", Pkg.dir("OsuBot", "config.yml"))'

CMD ["julia", "/root/app/bin/bot.jl"]

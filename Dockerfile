FROM julia:0.6.0

ENV APP /root/OsuBot
ENV KEEP_PKGS python3-pip
ENV PKGS hdf5-tools git unzip build-essential
ENV PYTHON /usr/bin/python3
ENV PYTHONPKGS praw

RUN mkdir -p $APP
COPY . $APP

RUN apt-get update && \
    apt-get -y install $KEEP_PKGS && \
    apt-get -y install $PKGS && \
    pip3 install $PYTHONPKGS && \
    cd $APP && \
    mv oppai /usr/local/bin/ && \
    julia -e 'Pkg.clone(pwd()); cp("config.yml", Pkg.dir("OsuBot", "config.yml")); using OsuBot' && \
    apt-get -y purge $PKGS && \
    apt-get -y autoremove

CMD ["julia", "/root/OsuBot/bin/bot.jl"]

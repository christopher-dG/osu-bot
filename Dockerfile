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
    git clone https://github.com/Francesco149/oppai-ng oppai && \
    cd oppai && \
    ./build && \
    install oppai /usr/local/bin/oppai && \
    cd .. && \
    rm -rf oppai && \
    pip3 install $PYTHONPKGS && \
    cd $APP && \
    bash -c "source config.sh; julia -e 'Pkg.clone(pwd()); using OsuBot'" && \
    apt-get -y purge $PKGS && \
    apt-get -y autoremove

ENTRYPOINT ["/root/OsuBot/bin/entrypoint.sh"]

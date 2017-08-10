FROM ruby:2.4.1

ENV APP /root/app
ENV GEMS httparty markdown-tables redd

RUN mkdir -p $APP/log/maps && \
    mkdir $APP/lib
COPY config.yml $APP/config.yml
COPY lib $APP/lib/
COPY oppai /tmp/oppai/
RUN /tmp/oppai/build.sh
RUN touch $APP/log/rolling.log && \
    mv oppai /usr/local/bin/oppai && \
    rm -rf /tmp/oppai && \
    gem install $GEMS

CMD ["ruby", "/root/app/lib/bot.rb"]

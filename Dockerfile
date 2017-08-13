FROM ruby:2.4.1

ENV APP /root/app
ENV GEMS httparty markdown-tables redd

RUN mkdir -p $APP

COPY . $APP

RUN $APP/oppai/build.sh && \
    mv oppai /usr/local/bin/oppai && \
    rm -rf $APP/oppai && \
    gem install $GEMS

CMD ["ruby", "/root/app/lib/bot.rb"]

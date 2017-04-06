echo "\n$(date): (re)starting\n" >> ~/osu!-bot/logs/startup.log
while true; do
    ruby ~/osu!-bot/lib/osu!-bot.rb
    sleep 10
done

echo "\n$(date): (re)starting\n" >> ../logs/startup.log
while true; do
    ruby ~/osu!-bot/lib/osu!-bot.rb
    sleep 10
done

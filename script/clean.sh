# Keep the rolling log file under 5 MB.
tail -c 5MB ~/osu!-bot/logs/rolling.log > temp
mv temp ~/osu!-bot/logs/rolling.log

# Zip all the single-run logs to save space.
zip ~/osu!-bot/logs/logs.zip $(find ~/osu!-bot/logs -type f -regex ".*[0-9]\.log")
rm $(find ~/osu!-bot/logs -type f -regex ".*[0-9]\.log")

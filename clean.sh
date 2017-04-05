# Keep the rolling log file under 10 MB.
tail -100000 logs/rolling.log > temp
mv temp logs/rolling.log

# Delete single-run log files older than 10 days.
for file in $(find -regex ".*logs/.*[0-9]\.log" -mtime +10); do
    rm $file
done

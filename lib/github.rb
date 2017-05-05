# coding: utf-8

require 'github_api'
require 'redd'

require_relative 'consts'
require_relative'utils'

if __FILE__ == $0
  start_time = Time.now
  LOG = "#{File.dirname(LOG)}/github.log"
  issues = Github::Client::Issues.new(
    basic_auth: "christopher-dG:#{GITHUB_PASSWORD}",
    user: 'christopher-dG',
    repo: 'osu-bot'
  )
  reddit = Redd.it(
    user_agent: 'osu!-bot',
    client_id: REDDIT_CLIENT_ID,
    secret: REDDIT_SECRET,
    username: 'osu-bot',
    password: REDDIT_PASSWORD,
  )
  bot = reddit.me
  me = reddit.user('PM_ME_DOG_PICS_PLS')
  c = 0

  bot.comments.each do |comment|
    comment.reload.replies.each do |r|
      if !TROLLS.include?(r.author.name) && r.body.start_with?("!error") &&
         !bot.saved.any? {|c| c.id == r.id}
        # Generate the issue title and text.
        reply_text = "> #{r.body[6..-1].split("\n").join("\n> ")}".strip
        title = "Auto-generated issue by /u/#{r.author.name}"
        link = comment.link_id[3..-1]
        body = "Comment on [#{comment.link_title.gsub('#', '\# ')}](https://redd.it/#{link}):\n\n#{reply_text}"
        pm = '[New issue](https://github.com/christopher-dg/osu-bot/issues)'
        log("#{title}\n#{body}")
        if !DRY
          # Open the issue.
          issues.create(title: title, body: body)
          r.save
          me.send_message(subject: 'osu!-bot', text: pm)
        else
          puts("Title: #{title}\nBody: #{body}\nPM: #{pm}")
        end
        c += 1
      end
    end
  end

  File.open("#{File.dirname(LOG)}/rolling.log", 'a') do |f|
    f.write("Opened #{c} GitHub issue#{plur(c)}\n")
    if DEBUG
      f.write("GitHub bot took #{round(Time.now - start_time, 3)} seconds\n\n")
    else
      f.write("\n")
    end
  end

end

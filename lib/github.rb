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

      if r.body.start_with?("!error") &&
         !bot.saved.any? {|c| c.id == r.id}
        # Generate the issue title and text.
        reply_text = "> #{r.body[6..-1].split("\n").join("\n> ")}".strip
        # URL not working yet.
        # link = "https://reddit.com/r/osugame/comments'#{comment.link_id}/"
        # link += comment.link_title.gsub(/\W/, '').gsub(' ', '_')
        # link_md = "[#{comment.link_title}](#{link})"
        # body += "Comment on '#{link_md}':\n\n#{reply_text}"
        title = "Auto-generated issue by /u/#{r.author.name}"
        body = "Comment on '#{comment.link_title.gsub('#', '\# ')}':\n\n#{reply_text}"
        msg = '[New issue](https://github.com/christopher-dg/osu-bot/issues)'
        me.send_message(subject: 'osu!-bot', text: msg)

        log("#{title}\n#{body}")
        # Open the issue.
        !DRY && issues.create(title: title, body: body)
        r.save
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

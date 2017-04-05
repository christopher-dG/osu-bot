require 'github_api'
require 'redd'

require_relative 'consts'
require_relative'utils'

if __FILE__ == $0
  LOG = "#{File.dirname(LOG)}/github.log"
  issues = Github::Client::Issues.new(
    basic_auth: "christopher-dG:#{GITHUB_PASSWORD}",
    user: 'christopher-dG',
    repo: 'osu-bot'
  )
  me = Redd.it(
    user_agent: 'osu!-bot',
    client_id: REDDIT_CLIENT_ID,
    secret: REDDIT_SECRET,
    username: 'osu-bot',
    password: REDDIT_PASSWORD,
  ).me

  me.comments.each do |comment|
    comment.reload.replies.each do |r|

      if r.body.start_with?("!error") &&
         !me.saved.any? {|c| c.id == r.id && c.link_id == r.link_id}
        # Generate the issue title and text.
        reply_text = "> #{r.body[6..-1].split("\n").join("\n> ")}".strip
        # URL not working yet.
        # link = "https://reddit.com/r/osugame/comments'#{comment.link_id}/"
        # link += comment.link_title.gsub(/\W/, '').gsub(' ', '_')
        # link_md = "[#{comment.link_title}](#{link})"
        # body += "Comment on '#{link_md}':\n\n#{reply_text}"
        title = "Auto-generated issue by /u/#{r.author.name}"
        body = "Comment on '#{comment.link_title}':\n\n#{reply_text}"


        log("#{title}\n#{body}")
        # Open the issue.
        !DRY && issues.create(title: title, body: body)
        r.save
      end
    end
  end
end

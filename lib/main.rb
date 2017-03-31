require_relative 'osu-bot'

if __FILE__ == $0
  begin
    osu = get_sub
  rescue
    msg = "Reddit initialization failed.\n"
    File.open("#{LOG_DIR}/#{now}", 'a') {|f| f.write(msg)}
  else
    c = 0
    for post in osu.new
      if is_score_post(post) &&
         !post.comments.any? {|comment| comment.author.name == 'osu-bot'}
        player, map = search(post.title)
        if map != nil
          post.reply(gen_comment(post.title, map, player))
          post.upvote
          c += 1
        end
      end
    end
  ensure
    msg = "Made #{c} comment#{c == 0 || c > 1 ? 's' : ''}.\n"
    File.open("#{LOG_DIR}/#{now}", 'a') {|f| f.write(msg)}
  end
end

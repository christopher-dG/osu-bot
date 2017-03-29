require_relative 'linker-bot'

if __FILE__ == $0
  osu = get_sub
  c = 0
  for post in osu.new
    if is_score_post(post) &&
       !post.comments.any? {|comment| comment.author.name == 'map-linker-bot'}
      map = search(post.title)
      if map != nil
        puts(gen_comment(post.title, map))
        post.reply(gen_comment(post.title, map))
        c += 1
      end
    end
  end
  msg = "Made #{c} comment#{c == 0 || c > 1 ? 's' : ''}.\n"
  File.open("#{LOG_PATH}/#{now}", 'a') {|f| f.write(msg)}
end

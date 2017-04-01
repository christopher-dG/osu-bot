require_relative 'osu-bot'

if __FILE__ == $0
  begin
    osu = get_sub(test=ARGV.to_s == '["test"]')
  rescue
    log("Reddit initialization failed.\n")
  else
    c = 0
    for post in osu.new
      if is_score_post(post) &&
         !post.comments.any? {|comment| comment.author.name == 'osu-bot'}
        player, map = search(post.title)
        if map != nil
          post.reply(gen_comment(map, player, get_mods(post.title)))
          post.upvote
          c += 1
        end
      end
    end
  ensure
    log("Made #{c} comment#{c == 0 || c > 1 ? 's' : ''}.\n")
  end
end

# Comment on an arbitrarily titled post.
# Arguments:
#   title: Reddit post title.
#   beatmap_id: ID of the played map.
#   player_id: Identifier for the player, either username or user ID.
#   type='': type of player id proveded. 'string' for username, 'id' for ID.
#   lim=25: Number most recent posts to look through.
def manual_comment(title, beatmap_id, player_id, type='', lim=25)
  osu = get_sub
  for post in osu.new
    if post.title == title
      map = request('beatmaps', {'b' => beatmap_id})
      player = request('user', {'u' => player_id, 'type' => type})
      mods = get_mods(title)
      comment = gen_comment(map, player, mods)
      puts("Comment on '#{post.title}'? (y/n)")
      confirm = gets.chomp
      'y'.casecmp(confirm) == 0 && post.reply(comment)
    end
    break
  end
  nil
end

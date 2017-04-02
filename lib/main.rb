require_relative 'osu-bot'

def run(test: false)
  c = 0
  begin
    osu = get_sub(unittest: ARGV.to_s == '["test"]')
  rescue
    log(msg: "Reddit initialization failed.\n")
  else
    for post in osu.new
      if (is_score_post(post))
        if test || !post.comments.any? {|comment| comment.author.name == 'osu-bot'}
          player, map = search(post.title)
          if map != nil
            comment = gen_comment(map, player, get_mods(post.title))
            if !test
              post.reply(comment)
              post.upvote
              c += 1
            else
              log(msg: "#{comment}\n---\n")
            end
          end
        end
      end
    end
  ensure
    log(msg: "Made #{c} comment#{c == 0 || c > 1 ? 's' : ''}.\n")
  end
end

# Comment on an arbitrarily titled post.
# Arguments:
#   title: Reddit post title.
#   beatmap_id: ID of the played map.
#   player_id: Identifier for the player, either username or user ID.
#   type: '': type of player id proveded. 'string' for username, 'id' for ID.
#   lim: 25: Number most recent posts to look through.
def manual_comment(title, beatmap_id, player_id, type: '', lim: 25)
  osu = get_sub
  for post in osu.new
    if post.title == title
      map = request('beatmaps', {'b' => beatmap_id})
      player = request('user', {'u' => player_id, 'type' => type})
      comment = gen_comment(map, player, get_mods(title), mode: map['mode'])
      puts(comment)
      puts("Post comment to '#{tile}'?")
      confirm = gets
      if confirm.downcase.chomp == 'y'
        post.reply(comment)
        post.upvote
      end
      break
    end
  end
  nil
end

def log(msg: '',  n: 10)
  if msg.empty?
    for file in `ls #{File.dirname(LOG)} | tail -#{n}`.split("\n")
      File.open(File.expand_path("#{File.dirname(LOG)}/#{file}")) {|f| puts("#{file}:\n#{f.read}----")}
    end
  else
    File.open(LOG, 'a') {|f| f.write(msg)}
  end
  return nil
end


__FILE__ == $0 && run

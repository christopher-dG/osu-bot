require 'date'
require 'httparty'
require 'redd'
require_relative 'consts'
require_relative 'fetching'
require_relative 'utils'
require_relative 'parsing'
require_relative 'osu-bot'

def run(test: false)
  c = 0
  begin
    osu = get_sub
  rescue
    log(msg: "Reddit initialization failed.\n")
  else
    for post in osu.new
      if is_score_post(post)
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



__FILE__ == $0 && run(ARGV.length == 1)

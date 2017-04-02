# Make a string as easy to compare as possible. Technically this allows for
#   comparison errors, but they're extremely unlikely in our use case.
def bleach(string) string.downcase.gsub(/\s/, '') end

# Compare two strings by bleaching them first.
def bleach_cmp(x, y) bleach(x) == bleacH(y) end

# Get the current date and time.
def now() `date +"%m-%d-%Y_%H:%M"`.chomp end

# Get a subreddit, /r/osugame by default.
def get_sub(sub: 'osugame')
  Redd.it(
    user_agent: 'Redd:osu!-bot:v0.0.0',
    client_id: CLIENT_ID,
    secret: SECRET,
    username: 'osu-bot',
    password: PASSWORD,
  ).subreddit(sub)
end

# Convert a number of seconds to a 'mm:ss' timestamp. Can accept s as a string.
def convert_s(n)
  s = s.to_i
  h = s / 60
  m = s % 60
  if m < 10
    return "#{h}:0#{m}"
  else
    return "#{h}:#{m}"
  end
end

# Get osu! API results in the form of an array or a hash.
def request(request, vars)
  suffix = "k=#{KEY}"
  if request == 'user_recent'
    suffix += "&u=#{vars['u']}&limit=50"
    is_list = true
  elsif request == 'beatmaps'
    suffix += "&b=#{vars['b']}&limit=1"
    is_list = false
  elsif request == 'user_best'
    suffix += "&u=#{vars['u']}&limit=1"
    is_list = false
  elsif request == 'user'
    suffix += "&u=#{vars['u']}&event_days=31"
    is_list = false
  elsif request == 'scores'
    suffix += "&u=#{vars['u']}&b=#{vars['b']}&limit=1"
    is_list = false
  end
  if vars.keys.include?('t') && !['string', 'id'].include?(vars['t'])
    suffix += "&type=#{vars['type']}"
  end
  if vars.keys.include?('m') && vars['m'].to_i >= 0 && vars['m'].to_i <= 3
    suffix += "&m=#{vars['m']}&a=1"
  end

  url = "#{URL}/api/get_#{request}?#{suffix}"
  response = HTTParty.get(url).parsed_response
  return is_list ? response : response[0]
  end
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

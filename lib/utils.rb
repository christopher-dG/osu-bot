# Make a string as easy to compare as possible. Technically this allows for
# comparison errors, but they're extremely unlikely in our use case.
def bleach(string) string.downcase.gsub(/\s/, '') end

# Compare two strings by bleaching them first.
def bleach_cmp(x, y) bleach(x) == bleach(y) end

# Round 'n' to 'd' decimal places as a string.
def round(n, d=0) n.to_f.round(d).to_s end

# Insert commas into large numbers.
def format_num(n) round(n).reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse end

# Return 's' if a given number is not 1, otherwise an empty string.
def plur(n) n == 1 ? '' : 's' end

# Format a map's title information.
def map_string(map) "#{map['artist']} - #{map['title']} [#{map['version']}]" end

# Get a subreddit, /r/osugame by default.
def get_sub
  sub = TEST ? 'osubottesting' : 'osugame'
  DEBUG && log("Getting subreddit: #{sub}")
  for i in 0..3
    begin
      reddit = Redd.it(
        user_agent: 'osu!-bot',
        client_id: REDDIT_CLIENT_ID,
        secret: REDDIT_SECRET,
        username: 'osu-bot',
        password: REDDIT_PASSWORD,
      ).subreddit(sub)
      return reddit
    end
  end
end

# Convert a number of seconds to a 'mm:ss' timestamp. Can accept s as a string.
def timestamp(n)
  DEBUG && log("Converting #{n} seconds to timestamp")
  s = n.to_i
  h = s / 60
  m = s % 60
  if m < 10
    time = "#{h}:0#{m}"
  else
    time = "#{h}:#{m}"
  end
  DEBUG && log("Converted to #{time}")
  return time
end

# Get osu! API results in the form of an array or a hash. Anything using this
# function should do its own error handling.
# u: user name or id
# b: beatmap id
# t: user type ('string', 'id')
# m: mode (0=standard)
def request(request, u: '', b: '', t: '', m: '')
  DEBUG && log("Making request with u: '#{u}', b: '#{b}', t: '#{b}', m: '#{m}'")
  time = Time.now
  suffix = "k=#{OSU_KEY}"
  if request == 'user_recent'
    suffix += "&u=#{u}&limit=50"
    is_list = true
  elsif request == 'beatmaps'
    suffix += "&b=#{b}&limit=1"
    is_list = false
  elsif request == 'user_best'
    suffix += "&u=#{u}&limit=1"
    is_list = false
  elsif request == 'user'
    suffix += "&u=#{u}&event_days=31"
    is_list = false
  elsif request == 'scores'
    suffix += "&u=#{u}&b=#{b}&limit=1"
    is_list = false
  end
  if ['string', 'id'].include?(t)
    suffix += "&type=#{t}"
  end
  if m.to_i >= 0 && m.to_i <= 3
    suffix += "&m=#{m}&a=1"
  end

  url = "#{OSU_URL}/api/get_#{request}?#{suffix}"
  DEBUG && log("Requesting data from #{url}")
  response = HTTParty.get(url).parsed_response
  DEBUG && log("Request from #{url} took #{Time.now - time} seconds")
  return is_list ? response : response[0]
end

# If 'msg' is supplied, write it to a log file. Otherwise, print out 'n' recent logs.
def log(msg='',  n: 10)
  if msg.empty?
    `ls #{File.dirname(LOG)} | tail -#{n}`.split("\n").each do |file|
      File.open(File.expand_path("#{File.dirname(LOG)}/#{file}")) do |f|
        puts("#{file}:\n#{f.read}----")
      end
    end
  else
    msg = msg.end_with?('.') ? msg : "#{msg}."
    File.open(LOG, 'a') {|f| f.write("#{msg}\n")}
    DEBUG && puts(msg)
  end
  return true
end

# Manually comment on an arbitrarily named Reddit post. Useful when a post has
# a bad title or when beatmap_search isn't working. 'type' indicates the type
# of player_id: 'string' or 'id'. If no modlist is given, one will be created
# from the title. 'limit' indicates how far to look into /new.
def manual_comment(title, map_name, map_id, player_id, type: 'string', mods: '', lim: 25)
  osu = get_sub
  osu.new.each do |post|
    if bleach_cmp(post.title, title)
      map = request('beatmaps', {'b' => map_id})
      player = request('user', {'u' => player_id, 'type' => type})
      post = ScorePost.new(
        title, mods: mods, manual: true, map: map, player: player, map_name: map_name
      )
      comment = markdown(post)
      puts("Post comment to '#{tile}'?")
      confirm = gets
      if confirm.downcase.chomp == 'y'
        post.reply(comment).distinguish(:sticky)
        post.upvote
      end
      break
    end
  end
  return nil
end

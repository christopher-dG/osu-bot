# Make a string as easy to compare as possible. Technically this allows for
# comparison errors, but they're extremely unlikely in our use case.
def bleach(string) string.downcase.gsub(/\s/, '') end

# Compare two strings by bleaching them first.
def bleach_cmp(x, y) bleach(x) == bleach(y) end

# Insert commas into large numbers.
def format_num(n) round(n).reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse end

# Return 's' if a given number is not 1, otherwise an empty string.
def plur(n) n == 1 ? '' : 's' end

# Format a map's title information.
def map_string(map) "#{map['artist']} - #{map['title']} [#{map['version']}]" end

# Write 'msg' to a log file, only if 'DEBUG' is set. !log(msg) is always true.
def log(msg) DEBUG && File.open(LOG, 'a') {|f| f.write("#{msg}\n")} && puts(msg) end

# Round 'n' to 'd' decimal places as a string.
def round(n, d=0)
  n = n.to_f.round(d)
  return (n.to_i == n ? n.to_i : n).to_s
end


# Get a subreddit, /r/osugame by default.
def get_sub
  sub = TEST ? 'osubottesting' : 'osugame'
  log("Getting subreddit '#{sub}'")
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
  log("Converting #{n} seconds to timestamp")
  s = n.to_i
  h = s / 60
  m = s % 60
  if m < 10
    time = "#{h}:0#{m}"
  else
    time = "#{h}:#{m}"
  end
  log("Converted to #{time}")
  return time
end

# Get osu! API results in the form of an array or a hash. Anything using this
# function should do its own error handling.
# u: user name or id
# b: beatmap id
# t: user type ('string', 'id')
# m: mode (0=standard)
def request(request, u: '', b: '', t: '', m: '')
  log("Making request with u: '#{u}', b: '#{b}', t: '#{t}', m: '#{m}'")
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
  safe_url = url.sub(OSU_KEY, '$private_key')
  log("Requesting data from #{safe_url}")
  response = HTTParty.get(url).parsed_response
  log("Request from #{safe_url} took #{round(Time.now - time, 5)} seconds")
  return is_list ? response : response[0]
end

# Manually comment on an arbitrarily named Reddit post. Useful when a post has
# a bad title or when beatmap_search isn't working. 'player' and 'map' values
# should be obtained via 'request'. 'limit' indicates how far to look into /new.
# Example:
# => title = "Cookiezi | kradness&Reol - Remote Control [Max Control!] +HDDT
# => player = request('user', u: "Cookiezi")
# => map = request('beatmaps', b: '774965')
# => mods = ['HD', 'DT']
# => manual_comment(title: title, player: player, map: map, mods: mods)
def manual_comment(title:, player:, map:, mods:, lim: 25)
  # Sanity checks.
  (title.class != String || player.class != Hash || map.class != Hash ||
   mods.class != Array) && raise('Arguments are of the wrong type')

  osu = get_sub
  osu.new.each do |p|
    if bleach_cmp(p.title, title)
      post = ScorePost.new(
        title: title, manual: true, player: player, map: map, mods: mods
      )
      comment = markdown(post)
      puts("Comment:\n\n#{comment}\n\n")
      puts("Post comment to '#{title}'?\n(y) to post: ")
      confirm = gets
      if confirm.downcase.chomp == 'y'
        p.reply(comment).distinguish(:sticky)
        p.upvote
      end
      break
    end
  end
  return nil
end

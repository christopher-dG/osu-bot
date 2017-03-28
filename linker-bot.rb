require 'httparty'
require 'redd'

KEY = File.open('key').read.chomp  # osu! API key.
PASSWORD = File.open('pass').read.chomp  # Reddit password.
SECRET = File.open('secret').read.chomp  # Reddit app secret.

# Use a Reddit post title to search for a beatmap.
# Arguments: title = Reddit post title.
# Returns: dictionary with beatmap information, or nil.
def search(title)
  tokens = title.split('|')
  player = tokens[0].strip
  map = tokens[1]
  song = map[0...map.index('[')].strip  # Artist - Title
  diff = map[map.index('[')..map.index(']')]  # [Diff Name]
  url = "https://osu.ppy.sh/api/get_user?k=#{KEY}&u=#{player}&type=string"

  begin
    response = HTTParty.get(url)
  rescue
    return nil
  end

  if response.parsed_response.empty?
    return nil
  end

  events = response.parsed_response[0]['events']
  full_name = "#{song} #{diff}"
  map_id = -1
  
  for event in events
    if event['display_html'].downcase.include?(full_name.downcase)
      map_id = event['beatmap_id']
    end
  end

  if map_id == -1
    return nil
  end

  url = "https://osu.ppy.sh/api/get_beatmaps?k=#{KEY}&b=#{map_id}"

  begin
    response = HTTParty.get(url)
  rescue
    return nil
  end

  return response.parsed_response[0]
end

# Comment on a score post with relevant beatmap information.
def comment(post, map)
  text = ""
  link_url = "https://osu.ppy.sh/b/#{map['beatmap_id']})"
  link_label = "#{map['artist']} - #{map['title']} [#{map['version']}]"
  creator_url = "https://osu.ppy.sh/u/#{map['creator']}"
  stars = map['difficultyrating'].to_f.round(2)
  gh_url = 'https://github.com/christopher-dG/osu-map-linker-bot'
  dev_url = 'https://reddit.com/u/PM_ME_DOG_PICS_PLS'

  text += "Beatmap: [#{link_label}](#{link_url}\n\n"
  text += "Creator: [#{map['creator']}](#{creator_url})\n\n"
  text += "SR: #{stars} - AR: #{map['diff_approach']} - "
  text += "OD: #{map['diff_overall']} - HP: #{map['diff_drain']}\n\n"
  text += "I'm a bot. [Source](#{gh_url}) | [Developer](#{dev_url})"

  post.reply(text)
end

# Criteria for a post being classified as a score post.
def is_score_post(post)
  return /\|.*-.*\[.*\]/ =~ post.title && !post.is_self
end

reddit = Redd.it(
  user_agent: 'Redd:osu!-map-linker-bot:v0.0.0',
  client_id: 'OxznkS-LjaEH3A',
  secret: SECRET,
  username: 'map-linker-bot',
  password: PASSWORD,
)
osugame = reddit.subreddit('osugame')
while true
  for post in osugame.new
    if is_score_post(post)
      if !post.comments.any? {|c| c.author.name == 'map-linker-bot'}
        map = search(post.title)
        if map != nil
          comment(post, map)
        end
      end
    end
  end
  sleep(300)  # Wait 5 minutes.
end

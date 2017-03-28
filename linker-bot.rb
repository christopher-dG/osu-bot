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
  full_name = "#{song} #{diff}".gsub!('&', '&amp;')
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
  gh_url = 'https://github.com/christopher-dG/osu-map-linker-bot'
  dev_url = 'https://reddit.com/u/PM_ME_DOG_PICS_PLS'

  mods = "+HDHR"  # Todo: Parse mods.
  `curl https://osu.ppy.sh/osu/#{map['beatmap_id']} > map.osu`
  oppai = `oppai/oppai map.osu #{mods}`

  sr = map['difficultyrating'].to_f.round(2)
  ar = map['diff_approach']
  cs = map['diff_size']
  od = map['diff_overall']
  hp = map['diff_drain']
  mod_sr = /[0-9]*\.[0-9]*\sstars/.match(oppai).to_s.split(' ')[0].to_f.round(2)
  mod_ar = /ar[0-9][0-9]?(\.[0-9][0-9]?)?/.match(oppai).to_s[2..-1]
  mod_ar = mod_ar.include?('.') ? mod_ar.to_f : mod_ar.to_i
  mod_cs = /cs[0-9][0-9]?(\.[0-9][0-9]?)?/.match(oppai).to_s[2..-1]
  mod_cs = mod_cs.include?('.') ? mod_cs.to_f : mod_cs.to_i
  mod_od = /od[0-9][0-9]?(\.[0-9][0-9]?)?/.match(oppai).to_s[2..-1]
  mod_od = mod_od.include?('.') ? mod_od.to_f : mod_od.to_i
  # Oppai does not handle HP drain.
  if mods.include?("EZ")
    mod_hp = (hp.to_f * 0.5).round(2)
    mod_hp = mod_hp.to_i == mod_hp ? mod_hp.to_i : mod_hp
  elsif mods.include?("HR")
    mod_hp = (hp.to_f * 1.4).round(2)  # Todo: Verify max drain = 10.
    mod_hp = mod_hp > 10 ? 10 : mod_hp.to_i == mod_hp ? mod_hp.to_i : mod_hp
  end
  
  text += "Beatmap: [#{link_label}](#{link_url}\n\n"
  text += "Creator: [#{map['creator']}](#{creator_url})\n\n"

  text += "SR: #{sr} - AR: #{ar} - CS: #{cs} - OD: #{od} - HP: #{hp}\n\n"

  if !mods.empty?
    text += "#{mods}:"
    text += "SR: #{mod_sr} - AR: #{mod_ar} - CS: #{mod_cs} - OD: #{mod_od} - HP: #{mod_hp}\n\n"
  end

  text += "^(I'm a bot. )[^Source](#{gh_url})^( | )[^Developer](#{dev_url})"

  puts text
  # post.reply(text)
end

# Criteria for a post being classified as a score post.
def is_score_post(post)
  return /\|.*-.*\[.*\]/ =~ post.title && !post.is_self
end

if __FILE__ == $0
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
end

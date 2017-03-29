#!/usr/bin/env ruby

require 'httparty'
require 'redd'

KEY = File.open('key').read.chomp  # osu! API key.
PASSWORD = File.open('pass').read.chomp  # Reddit password.
SECRET = File.open('secret').read.chomp  # Reddit app secret.
OSUGAME = Redd.it(
  user_agent: 'Redd:osu!-map-linker-bot:v0.0.0',
  client_id: 'OxznkS-LjaEH3A',
  secret: SECRET,
  username: 'map-linker-bot',
  password: PASSWORD,
).subreddit('osugame')

# Use a Reddit post title to search for a beatmap.
# Arguments:
#   title = Reddit post title.
# Returns: dictionary with beatmap data, or nil in case of an error.
def search(title)
  begin
    tokens = title.split('|')
    player = tokens[0].strip
    map = tokens[1]
    song = map[0...map.index('[')].strip  # Artist - Title
    diff = map[map.index('[')..map.index(']')]  # [Diff Name]

    url = "https://osu.ppy.sh/api/get_user?k=#{KEY}&u=#{player}&type=string"
    response = HTTParty.get(url)

    full_name = "#{song} #{diff}"  # Artist - Title [Diff Name]
    full_name.gsub!('&', '&amp;')

    events = response.parsed_response[0]['events']
    for event in events
      if event['display_html'].downcase.include?(full_name.downcase)
        map_id = event['beatmap_id']
      end
    end

    url = "https://osu.ppy.sh/api/get_beatmaps?k=#{KEY}&b=#{map_id}"
    response = HTTParty.get(url)
    return response.parsed_response[0]
  rescue
    msg = "Map retrieval failed for: #{title}"
    File.open(File.join('logs', now), 'w') {|f| f.write(msg)}
    return nil
  end
end

# Get diff SR, AR, OD, CS, and HP for nomod and with a given set of mods.
# Arguments:
#   map: Dictionary with beatmap data.
#   mods: Mod string, i.e. "+HDDT" or "+HRFL".
# Returns: Dictionary with [nomod, mod-adjusted] arrays as values, or just
#   [nomod] arrays if the mods (or lack thereof) do not affect the values.
def get_diff_info(map, mods)
  sr = map['difficultyrating'].to_f.round(2)
  ar = map['diff_approach']
  cs = map['diff_size']
  od = map['diff_overall']
  hp = map['diff_drain']

  return_nomod = Proc.new do
    return {'SR' => [sr], 'AR' => [ar], 'CS' => [cs], 'OD' => [od], 'HP' => [hp]}
  end

  ignore = ['HD', 'NF', 'SD', 'PF', 'SO', 'AP', 'RL']
  if !mods.empty?
    mod_list = mods[1..-1].scan(/../)
  end
  if mods.empty? || mod_list.all? {|m| ignore.include?(m)}
    return_nomod.call
  end

  ez_hp_scalar = 0.5
  hr_hp_scalar = 1.4
  hp_max = 10  # Todo: verify this.

  begin
    url = "https://osu.ppy.sh/osu/#{map['beatmap_id']}"
    `curl #{url} > map.osu`
    oppai = `./oppai/oppai map.osu #{mods}`
    File.delete('map.osu')
  rescue
    msg = "\`Downloading or analyzing the file at #{url}\` failed."
    File.open(File.join('logs', now), 'w') {|f| f.write(msg)}
    return_nomod.call
  end

  parse_oppai = Proc.new do |target, text|
    /#{target}[0-9][0-9]?(\.[0-9][0-9]?)?/.match(text).to_s[2..-1].to_f
  end

  m_sr = /[0-9]*\.[0-9]*\sstars/.match(oppai).to_s.split(' ')[0].to_f.round(2)
  m_ar = parse_oppai.call('ar', oppai)
  m_ar = m_ar.to_i == m_ar ? m_ar.to_i : m_ar
  m_cs = parse_oppai.call('cs', oppai)
  m_cs = m_cs.to_i == m_cs ? m_cs.to_i : m_cs
  m_od = parse_oppai.call('od', oppai)
  m_od = m_od.to_i == m_od ? m_od.to_i : m_od

  # Oppai does not handle HP drain.
  if mods.include?("EZ")
    m_hp = (hp.to_f * ez_hp_scalar).round(2)
    m_hp = m_hp.to_i == m_hp ? m_hp.to_i : m_hp
  elsif mods.include?("HR")
    m_hp = (hp.to_f * hr_hp_scalar).round(2)
    m_hp = m_hp > hp_max ? hp_max : m_hp.to_i == m_hp ? m_hp.to_i : m_hp
  else
    m_hp = hp
  end

  return {
    'SR' => [sr, m_sr], 'AR' => [ar, m_ar], 'CS' => [cs, m_cs],
    'OD' => [od, m_od], 'HP' => [hp, m_hp],
  }
end

# Generate the text to be commented.
# Arguments:
#   post: Reddit post being commented on.
#   map: Beatmap data.
def gen_comment(post, map)
  text = ""
  link_url = "https://osu.ppy.sh/b/#{map['beatmap_id']})"
  link_label = "#{map['artist']} - #{map['title']} [#{map['version']}]"
  creator_url = "https://osu.ppy.sh/u/#{map['creator']}"
  gh_url = 'https://github.com/christopher-dG/osu-map-linker-bot'
  dev_url = 'https://reddit.com/u/PM_ME_DOG_PICS_PLS'

  t = post.title
  mods_start = t.index('+', t.index(']'))  # First '+' after the diff name.
  mods = mods_start != nil ? t[mods_start...t.index(' ', mods_start)] : ''  # '+Mods'

  diff = get_diff_info(map, mods)
  len = convert_s(map['total_length'].to_i)
  
  text += "Beatmap: [#{link_label}](#{link_url}\n\n"
  text += "Creator: [#{map['creator']}](#{creator_url})\n\n"
  text += "Length: #{len} - BPM: #{map['bpm']} - Plays: #{map['playcount']}\n\n"
  text += "SR: #{diff['SR'][0]} - AR: #{diff['AR'][0]} - CS: #{diff['CS'][0]} "
  text += "- OD: #{diff['OD'][0]} - HP: #{diff['HP'][0]}\n\n"

  if !mods.empty?
    text += "#{mods}:\n\n"
    text += "SR: #{diff['SR'][1]} - AR: #{diff['AR'][1]} - CS: #{diff['CS'][1]}"
    text += " - OD: #{diff['OD'][1]} - HP: #{diff['HP'][1]}\n\n"
  end

  text += "***\n\n"
  text += "^(I'm a bot. )[^Source](#{gh_url})^( | )[^Developer](#{dev_url})"

  return text
end

# Convert seconds to mm:ss.
def convert_s(s)
  h = s / 60
  m = s % 60
  if m < 10
    m = "0#{m}"
  end
  return "#{h}:#{m}"
end

# Format the current date and time.
def now()
  return `date +"%m-%d-%Y %k-%M"`.chomp
end

# Criteria for a post being classified as a score post.
def is_score_post(post)
  return /\|.*-.*\[.*\]/ =~ post.title && !post.is_self
end

if __FILE__ == $0
  for post in OSUGAME.new
    if is_score_post(post) &&
        !post.comments.any? {|c| c.author.name == 'map-linker-bot'}
      map = search(post.title)
      if map != nil
        post.reply(gen_comment(post, map))
      end
    end
  end
end

#!/usr/bin/env ruby

require 'httparty'
require 'redd'

DIR = File.expand_path(File.dirname(__FILE__))  # Absolute path to file folder.
KEY = File.open(File.join(DIR, 'key')).read.chomp  # osu! API key.
PASSWORD = File.open(File.join(DIR, 'pass')).read.chomp  # Reddit password.
SECRET = File.open(File.join(DIR, 'secret')).read.chomp  # Reddit app secret.
LOG_PATH = File.join(DIR, 'logs')  # Path to log files.

# Use a Reddit post title to search for a beatmap.
# Arguments:
#   title: Reddit post title.
# Returns:
#   Dictionary with beatmap data, or nil in case of an error.
def search(title)
  begin
    tokens = title.split('|')
    player = tokens[0].strip
    map = tokens[1]
    song = map[0...map.index('[')].strip  # Artist - Title
    diff = map[map.index('[')..map.index(']')]  # [Diff Name]

    url = "https://osu.ppy.sh/api/get_user?k=#{KEY}&u=#{player}&type=string"
    response = HTTParty.get(url)

    full_name = "#{song} #{diff}".gsub('&', '&amp;')  # Artist - Title [Diff Name]

    events = response.parsed_response[0]['events']
    for event in events
      if event['display_html'].downcase.include?(full_name.downcase)
        map_id = event['beatmap_id']
      end
    end

    url = "https://osu.ppy.sh/api/get_beatmaps?k=#{KEY}&b=#{map_id}"
    response = HTTParty.get(url)
    beatmap = response.parsed_response[0]
    beatmap.empty? && raise

    return beatmap
  rescue
    msg = "Map retrieval failed for \'#{title}\'.\n"
    File.open(File.join(LOG_PATH, now), 'a') {|f| f.write(msg)}
    return nil
  end
end

# Get diff SR, AR, OD, CS, and HP for nomod and with a given set of mods.
# Arguments:
#   map: Dictionary with beatmap data.
#   mods: Mod string, i.e. "+HDDT" or "+HRFL".
# Returns:
#   Dictionary with [nomod, mod-adjusted] arrays as values, or just [nomod]
#   arrays if the mods (or lack thereof) do not affect the values.
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
    msg = "\`Downloading or analyzing the file at #{url}\` failed.\n"
    File.open(File.join(LOG_PATH, now), 'a') {|f| f.write(msg)}
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

  {
    'SR' => [sr, m_sr], 'AR' => [ar, m_ar], 'CS' => [cs, m_cs],
    'OD' => [od, m_od], 'HP' => [hp, m_hp],
  }
end

# Generate the text to be commented.
# Arguments:
#   title: Reddit post title.
#   map: Beatmap data.
# Returns:
#   Comment text.
def gen_comment(title, map)
  text = ""
  link_url = "https://osu.ppy.sh/b/#{map['beatmap_id']})"
  link_label = "#{map['artist']} - #{map['title']} [#{map['version']}]"
  creator_url = "https://osu.ppy.sh/u/#{map['creator']}"
  gh_url = 'https://github.com/christopher-dG/osu-map-linker-bot'
  dev_url = 'https://reddit.com/u/PM_ME_DOG_PICS_PLS'

  m_start = title.index('+', title.index(']'))  # First '+' after the diff name.
  mods = m_start != nil ? title[m_start...title.index(' ', m_start)].gsub(',', '') : ''

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

  text
end

# Convert seconds to mm:ss.
# Arguments:
#   s: Number of seconds (Integer).
# Returns:
#   "m:ss" timestamp from s.
def convert_s(s)
  h = s / 60
  m = s % 60
  if m < 10
    m = "0#{m}"
  end
  "#{h}:#{m}"
end

# Format the current date and time.
# Returns:
#   "MM-DD-YYYY hh:mm"
def now
  `date +"%m-%d-%Y %k:%M"`.chomp
end

# Compares a post against some criteria for being classified as a score post.
# Arguments:
#   post: Reddit post.
# Returns:
#  Whether or not the post is considerd a score post.
def is_score_post(post)
  /\|.*-.*\[.*\]/ =~ post.title && !post.is_self
end

# Get the /r/osugame subreddit.
# Returns:
#   /r/osugame subreddit.
def get_sub
  Redd.it(
    user_agent: 'Redd:osu!-map-linker-bot:v0.0.0',
    client_id: 'OxznkS-LjaEH3A',
    secret: SECRET,
    username: 'map-linker-bot',
    password: PASSWORD,
  ).subreddit('osugame')
end

if __FILE__ == $0
  osu = get_sub
  c = 0
  for post in osu.new
    if is_score_post(post) &&
       !post.comments.any? {|comment| comment.author.name == 'map-linker-bot'}
      map = search(post.title)
      if map != nil
        post.reply(gen_comment(post.title, map))
        c += 1
      end
    end
  end
  msg = "Made #{c} comment#{c == 0 || c > 1 ? 's' : ''}."
  File.open(File.join(LOG_PATH, now), 'a') {|f| f.write("Made #{c} comments.\n")}
end

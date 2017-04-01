#!/usr/bin/env ruby

require 'httparty'
require 'redd'
require_relative 'consts'

# Get the mod combination from an integer.
# Arguments:
#   mods: integer representing modstrin.g
# Returns:
#   Modstring from `mods`.
def get_bitwise_mods(mods)
  cur = mods
  mod_list = []
  for mod in BITWISE_MODS.keys.reverse

    if cur == 0 && !mod_list.empty?
      mod_list.include?('NC') && mod_list.delete('DT')
      order = [
        'EZ', 'HD', 'HR', 'DT', 'NC', 'HR', 'FL',
        'NF', 'SD', 'PF', 'RL', 'AP', 'AT', 'SO',
      ]
      for m in order.reverse
        mod_list.delete(m) && mod_list.push(m)
      end
      return "+#{mod_list.reverse.join('')} "

    elsif mod <= cur
      mod_list.push(BITWISE_MODS[mod])
      cur -= mod
    end
  end
  return ''
end

# Get player name, song artist and title, and diff name from a post title.
# Arguments:
#   title: Reddit post title.
# Returns:
#   'player name', 'artist - title', '[diff name]' or nil if there are errors.
def split_title(title)
  tokens = title.split('|')
  player = tokens[0]
  paren = player.index('(')
  player = paren == nil ? player.strip : player[0...paren].strip
  map = tokens[1]
  song = map[0...map.rindex('[')].strip  # Artist - Title

  # 'p | artist-name-songname [d]' will break here, but that's just a bad title.
  if song.count('-') == 1
    /\s-\s/ !~ song && song.sub!('-', ' - ')
  end
  diff = map[map.rindex('[')..map.rindex(']')]  # [Diff Name]
  return player, song, diff
end

# Use a Reddit post title to search for a beatmap.
# Arguments:
#   title: Reddit post title
#   test_set={}: List of precomputed API results to test with.
# Returns:
#   Dictionary with beatmap data, or nil in case of an error.
def search(title, test_set={})
  begin
    player_name, song, diff = split_title(title)
    full_name = "#{song} #{diff}".gsub('&', '&amp;')  # Artist - Title [Diff Name]

    map_id = -1
    # Use the player's recent events. Score posts are likely to be at least top
    # 50 on the map, and this method takes less time than looking through recents.
    player = test_set.empty? ?
               request('user', {'u' => player_name, 't' => 'string'}) :
               test_set['user']
    events = test_set.empty? ? player['events'] : test_set['user']['events']

    for event in events
      if event['display_html'].downcase.include?(full_name.downcase)
        map_id = event['beatmap_id']
      end
    end

    if map_id == -1  # Use player's recent plays as a backup. This takes significantly longer.
      seen_ids = []  # Avoid making duplicate API calls.
      t = Time.now  # Log how long this takes.
      for play in request('user_recent', {'u' => player['user_id']})
        seen_ids.include?(play['beatmap_id']) && next
        seen_ids.push(play['beatmap_id'])

        id = play['beatmap_id']
        btmp = request('beatmaps', {'b' => id})

        compare = "#{btmp['artist']} - #{btmp['title']} [#{btmp['version']}]"
        if full_name.downcase == compare.downcase
          map_id = id
          break
        end
      end

      msg = "Iterating over recents took #{Time.now - t} seconds. "
      msg += "Map was #{map_id == -1 ? 'not ' : ''}found.\n"
      log(msg)

      map_id == -1 && raise
      # "http://osusearch.com/api/search?key=&title=Freedom+Dive&artist=xi&diff_name=FOUR+DIMENSIONS&order=play_count"
    end

    beatmap = request('beatmaps', vars={'b' => map_id})
    beatmap.empty? && raise
    return player, beatmap
  rescue
    log("Map retrieval failed for '#{title}'.\n")
    return nil, nil
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
  sr = map['difficultyrating'].to_f.round(2).to_s
  ar = map['diff_approach']
  cs = map['diff_size']
  od = map['diff_overall']
  hp = map['diff_drain']

  return_nomod = Proc.new do
    return {'SR' => [sr], 'AR' => [ar], 'CS' => [cs], 'OD' => [od], 'HP' => [hp]}
  end

  if !mods.empty?
    mod_list = mods[1..-1].scan(/../)
  end
  if mods.empty? || mod_list.all? {|m| IGNORE.include?(m)} ||
     !mod_list.all? {|m| MODS.include?(m)}
    return_nomod.call
  end

  ez_hp_scalar = 0.5
  hr_hp_scalar = 1.4
  hp_max = 10  # Todo: verify this.

  begin
    url = "#{URL}/osu/#{map['beatmap_id']}"
    `curl #{url} > map.osu 2> /dev/null`
    oppai = `#{OPPAI_PATH} map.osu #{mods}`
  rescue
    log("\`Downloading or analyzing the file at #{url}\` failed.\n")
    return_nomod.call
  ensure
    File.delete('map.osu')
  end

  parse_oppai = Proc.new do |target, text|
    val = /#{target}[0-9][0-9]?(\.[0-9][0-9]?)?/.match(text).to_s[2..-1].to_f
    val.to_i == val ? val.to_i.to_s : val.to_s
  end

  m_sr = /[0-9]*\.[0-9]*\sstars/.match(oppai).to_s.split(' ')[0].to_f.round(2).to_s
  m_ar = parse_oppai.call('ar', oppai)
  m_ar = m_ar.to_i == m_ar ? m_ar.to_i : m_ar
  m_cs = parse_oppai.call('cs', oppai)
  m_cs = m_cs.to_i == m_cs ? m_cs.to_i : m_cs
  m_od = parse_oppai.call('od', oppai)
  m_od = m_od.to_i == m_od ? m_od.to_i : m_od

  # Oppai does not handle HP drain.
  if mods.include?("EZ")
    m_hp = (hp.to_f * ez_hp_scalar).round(2)
    m_hp = m_hp.to_i == m_hp ? m_hp.to_i.to_s : m_hp.to_s
  elsif mods.include?("HR")
    m_hp = (hp.to_f * hr_hp_scalar).round(2)
    m_hp = m_hp > hp_max ? hp_max.to_s : m_hp.to_i == m_hp ? m_hp.to_i.to_s : m_hp.to_s
  else
    m_hp = hp
  end

  return {
    'SR' => [sr, m_sr], 'AR' => [ar, m_ar], 'CS' => [cs, m_cs],
    'OD' => [od, m_od], 'HP' => [hp, m_hp],
  }
end

# Get mods from a Reddit post title.
# Arguments:
#   title: Post title.
# Returns:
#   Modstring formatted '+ModCombination', or an empty string if there are no mods.
def get_mods(title)
  title = title[title.index('|') + 1..-1]  # Drop the player name.
  m_start = title.index('+', title.rindex(']'))
  m_start = m_start != nil ? m_start + 1 : m_start

  is_modstring = Proc.new do |s|
    s.length % 2 == 0 && s.scan(/../).all? {|m| MODS.include?(m)}
  end

  if m_start != nil
    mods = /([A-Z]|,)*/.match(title[m_start..-1]).to_s.gsub(',', '')
    if is_modstring.call(mods)
      return "+#{mods}"
    end
  else
    tokens = title[title.rindex(']') + 1..-1].split(' ')
    for token in tokens
      if is_modstring.call(token)
        return "+#{token}"
      end
    end
  end
  return ''
end

# Get the status of a beatmap, and the effective date of that status.
# Arguments:
#   map: Beatmap being examined.
# Returns:
#   Map status, and effective date if the map is qualified, ranked, or loved.
def get_status(map)
  # '2' => 'Approved' but that's equivalent to 'Ranked'.
  status = {'1' => 'Ranked', '2' => 'Ranked', '3' => 'Qualified', '4' => 'Loved'}
  return status.key?(map['approved']) ?
           "#{status[map['approved']]} (#{map['approved_date'][0..9]})" : 'Unranked'
end

# Get pp values for 95%, 98%, 99%, and 100% acc.
# Arguments:
#   id: Beatmap id.
#   mods: Mods to be applied.
# Returns:
#   'pp95 | pp98 | pp99 | pp100' with all values rounded to the nearest integer,
#   or an empty string if anything fails.
def get_pp(id, mods)
  begin
    url = "#{URL}/osu/#{id}"
    `curl #{url} > map.osu 2> /dev/null`
    pp = []
    for acc in ['95%', '98%', '99%', '100%']
      pp.push(
        `#{OPPAI_PATH} map.osu #{acc} #{mods}`.
          split("\n")[-1][0..-3].to_f.round(0)
      )
      $? != 0 && raise
    end
  rescue
    pp = []
  ensure
    File.delete('map.osu')
  end
  return pp.join(' &#124; ')
end

# Adjust the BPM and length of a map for HT/DT/NC.
# Arguments:
#   map: Map being adjusted..
def adjust_bpm_length!(map, mods)
  bpm = map['bpm'].to_f.round(0)
  length = map['total_length'].to_i
  if mods =~ /DT|NC/
    map['bpm'] = (bpm * 1.5).to_f.round(0).to_s
    map['total_length'] = (length * 0.66).to_f.round(0).to_s
  elsif mods =~ /HT/
    map['bpm'] = (bpm * 0.66).to_f.round(0).to_s
    map['total_length'] = (length * 1.5).to_f.round(0).to_s
  end
end

# Generate the text to be commented.
# Arguments:
#   title: Reddit post title.
#   map: Beatmap data.
#   player: Player data.
# Returns:
#   Comment text.
def gen_comment(map, player, mods)
  link_url = "#{URL}/b/#{map['beatmap_id']}"
  link_label = "#{map['artist']} - #{map['title']} [#{map['version']}]"
  map_md = "[#{link_label}](#{link_url})"
  creator_url = "#{URL}/u/#{map['creator']}"
  creator_md = "[#{map['creator']}](#{creator_url})"
  gh_url = 'https://github.com/christopher-dG/osu-bot'
  dev_url = 'https://reddit.com/u/PM_ME_DOG_PICS_PLS'
  bpm = map['bpm'].to_f.round(0)
  length = convert_s(map['total_length'].to_i)
  status = get_status(map)
  pc = "#{map['playcount']} plays"
  d = '&#124;'  # Inline HTML delimiter.
  diff = get_diff_info(map, mods)
  m = diff['SR'].length == 2  # Whether or not the map has mods.
  cs, m_cs = diff['CS']
  ar, m_ar = diff['AR']
  od, m_od = diff['OD']
  hp, m_hp = diff['HP']
  sr, m_sr = diff['SR']
  pp = get_pp(map['beatmap_id'], '')

  text = "##### **#{map_md} by #{creator_md} | #{status} | #{pc}**\n\n"
  text += "#{m ? ' |' : ''}CS|AR|OD|HP|SR|BPM|Length|pp (95% #{d} 98% #{d} 99% #{d} 100%)\n"
  text += "#{m ? ':-:|' : ''}:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:\n"
  text += "#{m ? 'NoMod|' : ''}#{cs}|#{ar}|#{od}|#{hp}|#{sr}|#{bpm}|#{length}|#{pp}\n"

  if m
    adjust_bpm_length!(map, mods)
    bpm = map['bpm']
    m_pp = get_pp(map['beatmap_id'], mods)
    length = convert_s(map['total_length'].to_i)
    text += "#{mods}|#{m_cs}|#{m_ar}|#{m_od}|#{m_hp}|#{m_sr}|#{bpm}|#{length}|#{m_pp}\n\n"
  else
    text += "\n"
  end

  begin
    p_id = player['user_id']
    p_md = "[#{player['username']}](#{URL}/u/#{p_id})"
    p_rank = "##{player['pp_rank']}"
    p_pc = player['playcount']
    p_pp = player['pp_raw'].to_f.round(0)
    p_acc = "#{player['accuracy'].to_f.round(2)}%"

    top_play = request('user_best', {'u' => p_id})
    top_pp = top_play['pp'].to_f.round(0)
    top_map = request('beatmaps', {'b' => top_play['beatmap_id']})
    map_name = "#{top_map['artist']} - #{top_map['title']} [#{top_map['version']}]"
    top_mods = get_bitwise_mods(top_play['enabled_mods'].to_i)
    top_md = "[#{map_name}](#{URL}/b/#{top_play['beatmap_id']}) #{top_mods}(#{top_pp}pp)"
  rescue
    log("Fetching user information failed for '#{player['username']}}'.\n")
  else
    text += "Player|Rank|pp|Acc|Playcount|Top Play\n"
    text += ":-:|:-:|:-:|:-:|:-:|:-:\n"
    text += "#{p_md}|#{p_rank}|#{p_pp}|#{p_acc}|#{p_pc}|#{top_md}\n\n"
  end

  text += "***\n\n"
  text += "^(I'm a bot. )[^Source](#{gh_url})^( | )[^Developer](#{dev_url})"

  return text
end

def log(msg='', n=10)
  if msg.empty?
    for file in `ls #{LOG_DIR} | tail -#{n}`.split("\n")
      File.open(File.expand_path("#{LOG_DIR}/#{file}")) {|f| puts("#{file}:\n#{f.read}----")}
    end
  else
    File.open("#{LOG_DIR}/#{now}", 'a') {|f| f.write(msg)}
  end
end

def request(request, vars)
  suffix = "k=#{KEY}"
  if request == 'user_recent'
    suffix += "&u=#{vars['u']}&type=id&limit=50"
    is_list = true
  elsif request == 'beatmaps'
    suffix += "&b=#{vars['b']}"
    is_list = false
  elsif request == 'user_best'
    suffix += "&u=#{vars['u']}&type=id&limit=1"
    is_list = false
  elsif request == 'user'
    suffix += "&u=#{vars['u']}&event_days=31"
    if vars.keys.include?('t') && !['string', 'id'].include?(vars['t'])
      suffix += "&type=#{vars['type']}"
    end
    is_list = false
  end
  begin
    url = "#{URL}/api/get_#{request}?#{suffix}"
    puts url.sub(KEY, '$private_key')
    response = HTTParty.get(url).parsed_response
  rescue
    log("An HTTP request failed for '#{url}'.\n")
    return nil
  else
    return is_list ? response : response[0]
  end
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
  return "#{h}:#{m}"
end

# Format the current date and time.
# Returns:
#   "MM-DD-YYYY hh:mm"
def now
  return `date +"%m-%d-%Y_%H:%M"`.chomp
end

# Compares a post against some criteria for being classified as a score post.
# Arguments:
#   post: Reddit post.
# Returns:
#  Whether or not the post is considerd a score post.
def is_score_post(post)
  return post.title.strip =~ /[ -\]\[\w]{3,}\|.*\S.*-.*\S.*\[.*\S.*\]/ && !post.is_self
end

# Get either /r/osugame or /r/osubottesting subreddit.
# Arguments:
#   test=false: Whether or not we are testing.
# Returns:
#   /r/osugame subreddit, or /r/osubottesting if testing.
def get_sub(test=false)
  Redd.it(
    user_agent: 'Redd:osu!-bot:v0.0.0',
    client_id: CLIENT_ID,
    secret: SECRET,
    username: 'osu-bot',
    password: PASSWORD,
  ).subreddit(test ? 'osubottesting' : 'osugame')
end

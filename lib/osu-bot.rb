#!/usr/bin/env ruby

require 'httparty'
require 'redd'
require_relative 'consts'

# Get the mod combination from an integer.
# Arguments:
#   mods: integer representation of enabled mods.
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
#   ['player name', 'artist - title', 'diff name'] or nil if there are errors.
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
  diff = map[map.rindex('[') + 1...map.rindex(']')].strip
  return player, song, diff
end

# Use a Reddit post title to search for a beatmap.
# Arguments:
#   title: Reddit post title
#   test_set: {}: List of precomputed API results to test with.
# Returns:
#   Dictionary with beatmap data, or nil in case of an error.
def search(title, test_set: {})
  begin
    player_name, song, diff = split_title(title)
    full_name = "#{song} [#{diff}]".gsub('&', '&amp;')  # Artist - Title [Diff Name]

    if test_set.empty?
      player = request('user', {'u' => player_name, 'type' => 'string'})
      events = player['events']
    else
      player = test_set['player']
      events = player['events']
    end

    # Use the player's recent events. Score posts are likely to be at least top
    # 50 on the map, and this method takes less time than looking through recents.
    map_id = -1
    for event in events
      if event['display_html'].downcase.include?(full_name.downcase)
        map_id = event['beatmap_id']
        break
      end
    end

    if map_id == -1  # Use player's recent plays as a backup. This takes significantly longer.
      seen_ids = []  # Avoid making duplicate API calls.
      t = Time.now  # Log how long this takes.
      for play in request('user_recent', {'u' => player['user_id'], 'type' => 'id'})
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

      l = recents.length
      msg = "Iterating over #{l} recent#{l != 1 ? 's' : ''} took #{Time.now - t} seconds. "
      msg += "Map was #{map_id == -1 ? 'not ' : ''}found.\n"
      log(msg: msg)

      map_id == -1 && raise
      # "http://osusearch.com/api/search?key=&title=Freedom+Dive&artist=xi&diff_name=FOUR+DIMENSIONS&order=play_count"
    end

    beatmap = request('beatmaps', {'b' => map_id})
    beatmap.empty? && raise
    return player, beatmap
  rescue
    log(msg: "Map retrieval failed for '#{title}'.\n")
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
    log(msg: "\`Downloading or analyzing the file at #{url}\` failed.\n")
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
  return pp.join(" #{BAR} ")
end

# Adjust the BPM and length of a map for HT/DT/NC.
# Arguments:
#   bpm: Map BPM (int)
#   length: Map length in seconds (int).
# Returns, [adjusted bpm, adjusted length]
def adjust_bpm_length(bpm, length, mods)
  adj_bpm, adj_length = bpm, length
  if mods =~ /DT|NC/
    adj_bpm = (bpm * 1.5).to_f.round(0)
    adj_length = (length * 0.66).to_f.round(0)
  elsif mods =~ /HT/
    adj_bpm = (bpm * 0.66).to_f.round(0)
    adj_length = (length * 1.5).to_f.round(0)
  end
  return adj_bpm.to_i, adj_length.to_i
end

def gen_beatmap_md(map, mods)
  link_url = "#{URL}/b/#{map['beatmap_id']}"
  link_label = "#{map['artist']} - #{map['title']} [#{map['version']}]"
  link_md = "[#{link_label}](#{link_url})"
  creator_url = "#{URL}/u/#{map['creator']}"
  creator_md = "[#{map['creator']}](#{creator_url})"
  bpm = map['bpm'].to_f.round(0)
  length = convert_s(map['total_length'].to_i)
  status = get_status(map)
  pc = "#{map['playcount']} plays"
  diff = get_diff_info(map, mods)
  m = diff['SR'].length == 2  # Whether or not the map has mods.
  cs, m_cs = diff['CS']
  ar, m_ar = diff['AR']
  od, m_od = diff['OD']
  hp, m_hp = diff['HP']
  sr, m_sr = diff['SR']
  begin
    pp = get_pp(map['beatmap_id'], '')
  rescue
    log(msg: 'oppai exited with non-zero exit code.')
    return nil
  end
  combo = map['max_combo']
  map_md = "##### **#{link_md} by #{creator_md}**\n\n"
  map_md += "**#{combo}x | #{status} | #{pc}**\n\n"
  map_md += "***\n\n"
  map_md += "#{m ? ' |' : ''}CS|AR|OD|HP|SR|BPM|Length|pp (95% #{BAR} 98% #{BAR} 99% #{BAR} 100%)\n"
  map_md += "#{m ? ':-:|' : ''}:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:\n"
  map_md += "#{m ? 'NoMod|' : ''}#{cs}|#{ar}|#{od}|#{hp}|#{sr}|#{bpm}|#{length}|#{pp}\n"

  if m
    bpm, length = adjust_bpm_length(bpm.to_i, map['total_length'].to_i, mods)
    length = convert_s(length)
    m_pp = get_pp(map['beatmap_id'], mods)
    map_md += "#{mods}|#{m_cs}|#{m_ar}|#{m_od}|#{m_hp}|#{m_sr}|#{bpm}|#{length}|#{m_pp}\n\n"
  else
    map_md += "\n"
  end
  return map_md
end

# Generate the Markdown text to be commented.
# Arguments:
#   map: Beatmap data.
#   player: Player data.
#   mods: Mods that were added to the play.
#   mode='0': Gamemode played. 0 => standard, 1 => taiko, 2 => catch, 3 => mania.
# Returns:
#   Comment text.
def gen_comment(map, player, mods, mode: '0')
  text = gen_beatmap_md(map, mods)
  player_md = gen_player_md(player, mode: mode)
  player_md != nil && text += player_md

  gh_url = 'https://github.com/christopher-dG/osu-bot'
  dev_url = 'https://reddit.com/u/PM_ME_DOG_PICS_PLS'
  text += "***\n\n"
  text += "^(I'm a bot. )[^Source](#{gh_url})^( | )[^Developer](#{dev_url})"

  return text
end

# Get the player portion of a Reddit comment.
# Arguments:
#   player: Player data.
# Returns:
#   Markdown string.
def gen_player_md(player, mode: '0')
  begin
    p_id = player['user_id']
    p_md = "[#{player['username']}](#{URL}/u/#{p_id})"
    p_rank = "##{player['pp_rank']}"
    p_pc = player['playcount']
    p_pp = player['pp_raw'].to_f.round(0)
    p_acc = "#{player['accuracy'].to_f.round(2)}%"

    top_play = request('user_best', {'u' => p_id, 'type' => 'id', 'm' => mode})
    top_pp = top_play['pp'].to_f.round(0)
    top_map = request('beatmaps', {'b' => top_play['beatmap_id']})
    map_name = "#{top_map['artist']} - #{top_map['title']} [#{top_map['version']}]"
    top_mods = get_bitwise_mods(top_play['enabled_mods'].to_i)
    top_score = request(
      'scores',
      {'b' => top_map['beatmap_id'], 'u' => p_id, 'type' => 'id', 'm' => mode},
    )
    top_acc = get_acc(top_play)
    top_maxcombo = top_score['maxcombo']
    top_fc = top_play['countmiss'] == '0' ? 'FC ' : ''
    top_pf = top_play['perfect'] == '1'
    top_combo = top_pf ? '' : "(#{top_maxcombo}/#{top_map['max_combo']})"

    top_md = "[#{map_name}](#{URL}/b/#{top_play['beatmap_id']}) #{top_mods} "
    top_md += "#{top_fc}#{BAR} #{top_acc}% #{top_combo}(#{top_pp}pp)"
  rescue
    log(msg: "Fetching user information failed for '#{player['username']}}'.\n")
    return nil
  else
    player_md = "Player|Rank|pp|Acc|Playcount|Top Play\n"
    player_md += ":-:|:-:|:-:|:-:|:-:|:-:\n"
    player_md += "#{p_md}|#{p_rank}|#{p_pp}|#{p_acc}|#{p_pc}|#{top_md}\n\n"
    return player_md
  end
end


# Get a score's percentage accuracy.
# Arguments:
#   score: Score whose accuracy we are calculating.
# Returns:
#   Accuracy percentage rounded to two decimal places.
def get_acc(score)
  c = {
    300 => score['count300'].to_i, 100 => score['count100'].to_i,
    50 => score['count50'].to_i, 0 => score['countmiss'].to_i
  }
  o = c.values.sum.to_f  # Total objects.
  return ([c[300] / o, c[100] / o * 1/3.to_f, c[50] / o * 1/6.to_f].sum * 100).round(2)
end

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


  begin
    url = "#{URL}/api/get_#{request}?#{suffix}"
    puts url.sub(KEY, '$private_key')
    response = HTTParty.get(url).parsed_response
  rescue
    log(msg: "HTTP request failed for '#{url}'.\n")
    raise
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

# Compares a post against some criteria for being classified as a score post.
# Arguments:
#   post: Reddit post.
# Returns:
#  Whether or not the post is considerd a score post.
def is_score_post(post)
  return post.title.strip =~ /[\w\- \[\]]{3,}.*\|.*\S.*-.*\S.*\[.*\S.*\]/ && !post.is_self
end

# Get either /r/osugame or /r/osubottesting subreddit.
# Arguments:
#   unittest: false: Whether or not we are testing.
# Returns:
#   /r/osugame subreddit, or /r/osubottesting if testing.
def get_sub(unittest: false)
  Redd.it(
    user_agent: 'Redd:osu!-bot:v0.0.0',
    client_id: CLIENT_ID,
    secret: SECRET,
    username: 'osu-bot',
    password: PASSWORD,
  ).subreddit(unittest ? 'osubottesting' : 'osugame')
end

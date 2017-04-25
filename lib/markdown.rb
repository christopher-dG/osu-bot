# coding: utf-8

# Generate a Markdown a map's rank one score.
def rank_one(map)
  if ranked_status(map) == 'Unranked'
    log('Map is unranked, no rank one score to get') || raise
  end

  begin
    top_play = request('scores', b: map['beatmap_id'], m: map['mode'])
    top_player = request('user', u: top_play['username'], m: map['mode'])
  rescue
    log('An API request failed for the top play') || raise
  else
    rank_one = "#1: [#{top_play['username']}](#{OSU_URL}/u/#{top_player['user_id']}) ("
    rank_one_mods = mods_from_int(top_play['enabled_mods'])
    !rank_one_mods.empty? && rank_one += "+#{rank_one_mods.join} - "
    rank_one += "#{accuracy(top_play)}% - #{round(top_play['pp'])}pp)"
    show_rank_one = true
  end

  return rank_one
end

# Generate a markdown string with beatmap information.
# Raises an exception if anuthing goes wrong.
def beatmap_markdown(post)
  log("Generating beatmap Markdown for #{post.title}")
  map, mods = post.map, post.mods

  begin
    map_rank_one = rank_one(map)
    show_rank_one = true
  rescue
    show_rank_one = false
  end

  link_url = "#{OSU_URL}/b/#{map['beatmap_id']}"
  link_label = "#{map['artist']} - #{map['title']} [#{map['version']}]"
  link_md = "[#{map_string(post.map)}](#{link_url})"
  dl_md = "[(⇓)](#{OSU_URL}/d/#{map['beatmapset_id']})"
  creator_url = "#{OSU_URL}/u/#{map['creator']}"
  creator_md = "[#{map['creator']}](#{creator_url})"

  status = ranked_status(map)
  combo = "#{map['max_combo']}x max combo"
  pc = "#{format_num(map['playcount'])} plays"
  diff = diff_vals(map, mods)  # {key => [nomod, modded]}
  bpm = [round(map['bpm'])]
  length = [map['total_length']]
  # Todo: wait until #155 is fixed, then pass mods to this request to make sure
  # we're getting the right score.
  score = request(
    'scores', u: post.player['user_id'], t: 'id',
    b: map['beatmap_id'], m: map['mode'],
  )
  acc = accuracy(score)

  # oppai only works on standard, so don't show pp in any other modes.
  if map['mode'] == '0'
    begin
      pp = [oppai(map['beatmap_id'], mode: 'pp', acc: acc)]
      show_pp = true
    rescue
      show_pp = false
    end
  else
    show_pp = false
  end

  modded = diff['SR'].length == 2  # Whether the table will include modded values.
  log("Diff contains nomod #{modded ? 'and modded ' : ''}values")

  if modded
    adj_bpm, adj_length = adjusted_timing(bpm[0], length[0], mods)
    bpm.push(adj_bpm)
    length.push(timestamp(adj_length))
    begin
      modded_pp = oppai(
        map['beatmap_id'], mods: mods, mode: 'pp', acc: acc, nomod_vals: pp[0]
      )
    rescue
      show_pp = false
    end
  end

  if show_pp
    pp[0] = pp[0].join(" #{BAR} ")
    modded && pp.push(modded_pp.join(" #{BAR} "))
  end

  length[0] = timestamp(length[0])

  if modded
    headers, cols = [' '], [['NoMod', "+#{mods.join}"]]
  else
    headers, cols = [], []
  end

  headers += %w(CS AR OD HP SR BPM Length)
  cols += [diff['CS'], diff['AR'], diff['OD'], diff['HP'], diff['SR'], bpm, length]
  accs = [95, 98, 99, 100]
  accs.any? {|a| a == acc.to_f} || accs.push(acc)
  accs = accs.sort_by(&:to_f).map {|a| "#{a}%"}.join(" #{BAR} ")
  show_pp && headers.push("pp (#{accs})") && cols.push(pp)
  map_md = "##### **#{link_md} #{dl_md} by #{creator_md}**\n\n"

  if show_rank_one
    map_md += "**#{map_rank_one} || #{combo} || #{status} || #{pc}**\n\n"
  else
    map_md += "**#{combo} || #{status}**\n\n"
  end

  map_md += "***\n\n"

  begin
    map_md += table(headers, cols)
  rescue
    log('Table generation failed') || raise
  end

  log("Generated:\n'#{map_md}")
  return map_md
end

# Generate a Markdown string with player information.
# Raises an exception if anything goes wrong.
def player_markdown(player, mode)
  log("Generating player Markdown for '#{player['username']}'")

  # Get the player's top play.
  begin
    top_play_md = top_play(player, mode)
    show_top_play = true
  rescue
    log("Generating top play failed for '#{player['username']}'")
    show_top_play = false
  end

  id = player['user_id']
  headers = ['Player', 'Rank', 'pp', 'Acc', 'Playcount']
  cols = [
    ["[#{player['username']}](#{OSU_URL}/u/#{id})"],
    ["\##{format_num(player['pp_rank'])}"],
    [format_num(round(player['pp_raw']))],
    ["#{round(player['accuracy'], 2)}%"],
    [format_num(player['playcount'])],
  ]

  if show_top_play
    headers += ['Top Play']
    cols += [[top_play_md]]
  end

  log('Generating table for player')
  begin
    player_table = table(headers, cols)
  rescue
    raise
  end
  return player_table
end

# Generate a Markdown string to be commented. If neither the beatmap nor the
# player information can be generated, raises an exception.
# 'mode' is the game mode: 0 => standard, 1 => taiko, 2 => catch, 3 => mania.
def markdown(post)
  log("Generating comment Markdown for '#{post.title}'")

  # Get the beatmap information.
  begin
    beatmap_md = beatmap_markdown(post)
    show_beatmap = true
  rescue
    show_beatmap = false
  end

  # Get the player information.
  begin
    player_md = player_markdown(post.player, post.map['mode'])
    show_player = true
  rescue
    show_player = false
  end

  show_beatmap || show_player || log('Not enough info to display') || raise

  md = ''
  show_beatmap && md += "#{beatmap_md}\n"
  show_player && md += "\n#{player_md}\n"
  md += "***\n\n"
  md += "^(I'm a bot. )[^Source](#{GH_URL})^( | )[^Developer](#{DEV_URL})\n\n"
  md += "^(Notice a mistake? Read )[^this](#{GH_URL}/blob/master/reporting.md)^."

  log("Generated full comment:\n#{md}")
  return md
end

# Get a Markdown string for a player's top ranked play.
# Raises an exception if anything goes wrong.
def top_play(player, mode)
  log("Generating Markdown for top play of #{player['username']} (mode=#{mode})")
  begin
    play = request('user_best', u: player['user_id'], t: 'id', m: mode)
  rescue
    log("Request failed for player's top play") || raise
  end

  id = play['beatmap_id']

  begin
    map = request('beatmaps', b: id, m: mode)
  rescue
    log('Request failed for map of top play') || raise
  end

  mods = mods_from_int(play['enabled_mods'])
  # Pad mods with spaces to deal with double space in case of nomod plays.
  mods = mods.empty? ? ' ' : " +#{mods.join} "
  fc = play['countmiss'] == '0'

  # API results for converted maps don't include max combo.
  if fc || map['max_combo'].nil?
    combo = ''
  else
    combo = "(#{play['maxcombo']}/#{map['max_combo']}) "
  end

  md = "[#{map_string(map)}](#{OSU_URL}/b/#{id})#{mods}"
  md += "#{fc ? 'FC ' : ''}#{BAR} #{accuracy(play)}% "
  md += "#{combo}#{BAR} #{format_num(round(play['pp']))}pp"

  log("Generated:\n#{md}")
  return md
end

# Generate a Markdown table. headers and cols are one and two dimensional
# arrays, respectively. Pass align: 'l' for left alignment and 'r' for right
# alignment, otherwise cells will be centered. The data must represent a full
# table, i.e. all cols must be the same length and there must be the same number
# of cols as there are headers. All contents of headers and cols must be strings.
# table({"a"=>[1, 2], "b"=>[3, 4], "c"=>[5, 6]}) => "a|b|c\n:-:|:-:|:-:\n1|3|5\n2|4|6"
def table(headers, cols, align: '')
  log("Creating table.\nheaders: #{headers}\ncols: #{cols}")
  # Sanity checks.
  error = headers.empty? || cols.empty? || cols.all? {|r| r.empty?} ||
          cols.any? {|r| r.length != cols[0].length} ||
          headers.any? {|h| h.class != String} ||
          cols.any? {|col| col.any? {|c| c.class != String}}

  error && (log('Sanity checks failed') || raise)

  table = "#{headers.join('|')}\n"
  sep = align == 'l' ? ':-' : align == 'r' ? '-:' : ':-:'
  table += "#{([sep] * headers.length).join('|')}\n"
  (0...cols[0].length).each do |i|
    row = ''
    cols.each {|c| row += "#{c[i]}|"}
    row = row[0...-1]  # Remove trailing '|'.
    log("Row: #{row}")
    table += "#{row}\n"
  end

  table = table.chomp
  log("Generated table:\n#{table}")
  return table
end

# coding: utf-8

# Generate a Markdown a map's rank one score.
def rank_one(map)
  if ranked_status(map) == 'Unranked'
    log('Map is unranked, no rank one score to get')
    raise
  end

  begin
    top_play = request('scores', b: map['beatmap_id'], m: map['mode'])
    top_player = request('user', u: top_play['username'], m: map['mode'])
  rescue
    log('An API request failed for the top play')
    raise
  else
    rank_one = "#1: [#{top_play['username']}](#{OSU_URL}/u/#{top_player['user_id']}) ("
    rank_one_mods = mods_from_int(top_play['enabled_mods'])
    rank_one += "+#{rank_one_mods.join} - " if !rank_one_mods.empty?
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
  # Todo: wait until ppy/osu-api#155 is fixed, then pass mods to this request
  # to make sure we're getting the right score.
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
    pp.push(modded_pp.join(" #{BAR} ")) if modded
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
  accs.push(acc) if !accs.any? {|a| a == acc.to_f}
  accs = accs.sort_by(&:to_f).map {|a| "#{a}%"}.join(" #{BAR} ")
  if show_pp
    headers.push("pp (#{accs})")
    cols.push(pp)
  end
  map_md = "##### **#{link_md} #{dl_md} by #{creator_md}**\n\n"

  if show_rank_one
    map_md += "**#{map_rank_one} || #{combo} || #{status} || #{pc}**\n\n"
  else
    map_md += "**#{combo} || #{status}**\n\n"
  end

  map_md += "***\n\n"

  begin
    map_md += MarkdownTables.make_table(headers, cols)
  rescue
    log('Table generation failed')
    raise
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
    player_table = MarkdownTables.make_table(headers, cols)
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

  if !show_beatmap && !show_player
    log('Not enough info to display')
    raise
  end

  md = ''
  md += "#{beatmap_md}\n" if show_beatmap
  md += "\n#{player_md}\n" if show_player
  md += "***\n\n"
  md += "^(I'm a bot. )[^Source](#{GH_URL})^( | )[^Developer](#{DEV_URL})\n\n"
  md += "^(Notice a mistake? Read )[^this](#{GH_URL}/blob/master/reporting.md)^(. "
  md += "Also, my supporter is about to run out, )[^(pls help)](https://osu.ppy.sh/u/3172543)"
  md += '^( if you like my work.)'
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
    log("Request failed for player's top play")
    raise
  end

  id = play['beatmap_id']

  begin
    map = request('beatmaps', b: id, m: mode)
  rescue
    log('Request failed for map of top play')
    raise
  end

  mods = mods_from_int(play['enabled_mods'])
  # Pad mods with spaces to deal with double space in case of nomod plays.
  mods = mods.empty? ? ' ' : " +#{mods.join} "

  md = "[#{map_string(map)}](#{OSU_URL}/b/#{id})#{mods}#{BAR} "
  md += "#{accuracy(play)}% #{BAR} #{format_num(round(play['pp']))}pp"

  log("Generated:\n#{md}")
  return md
end

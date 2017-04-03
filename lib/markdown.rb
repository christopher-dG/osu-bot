# coding: utf-8

# Generate a markdown string with beatmap information.
# Returns an empty string if something goes wrong.
def beatmap_markdown(post)
  DEBUG && log("Generating beatmap Markdown for #{post.title}")
  map, mods = post.map, post.mods

  link_url = "#{OSU_URL}/b/#{map['beatmap_id']}"
  link_label = "#{map['artist']} - #{map['title']} [#{map['version']}]"
  link_md = "[#{post.map_name}](#{link_url})"
  dl_md = "[(⇓)](#{OSU_URL}/osu/#{map['beatmap_id']})"

  creator_url = "#{OSU_URL}/u/#{map['creator']}"
  creator_md = "[#{map['creator']}](#{creator_url})"
  combo = "#{map['max_combo']}x max combo"
  status = ranked_status(map)
  pc = "#{map['playcount']} plays"

  diff = diff_vals(map, mods)  # {key => [nomod, modded]}
  bpm = [round(map['bpm']).to_i]
  length = [map['total_length']]
  pp = [oppai(map['beatmap_id'], mode: 'pp')]

  show_pp = true
  m = diff['SR'].length == 2  # Whether the table will include modded values.
  DEBUG && log("Diff contains nomod#{m ? 'and modded' : ''} values")
  if m
    adj_bpm, adj_length = adjusted_timing(bpm[0], length[0], mods)
    bpm.push(adj_bpm)
    length.push(timestamp(adj_length))
    modded_pp = oppai(map['beatmap_id'], mods: mods, mode: 'pp')
    (modded_pp.nil? || pp.push(modded_pp.join(" #{BAR} "))) && show_pp = false
  end

  DEBUG && !show_pp && log('oppai modded pp calculation failed: not displaying pp')
  length[0] = timestamp(length[0])

  if m
    headers, cols = [' '], [['NoMod', "+#{mods.join}"]]
  else
    headers, cols = [], []
  end

  headers += ['CS', 'AR', 'OD', 'HP', 'SR', 'BPM', 'Length']
  cols += [diff['CS'], diff['AR'], diff['OD'], diff['HP'], diff['SR'], bpm, length]
  show_pp && headers.push("pp (95% #{BAR} 98% #{BAR} 99% #{BAR} 100%)") && cols.push(pp)

  map_md = "##### **#{link_md} #{dl_md} by #{creator_md}**\n\n"
  # Todo: Add map rank #1 to the second line.
  map_md += "**#{combo} | #{status} | #{pc}**\n\n"
  map_md += "***\n\n"
  map_md += table(headers, cols)

  map_md += "\n"
  # ???
  # if m
  #   map_md += mods_md
  # else
  #   map_md += "\n"
  # end

  DEBUG && log("Generated:\n'#{map_md}")
  return map_md
end

# Generate a Markdown string to be commented.
# mode is the game mode: 0 => standard, 1 => taiko, 2 => catch, 3 => mania.
def markdown(post)
  DEBUG && log("Generating comment Markdown for '#{post.title}'")
  md = beatmap_markdown(post)
  player_md = player_markdown(post.player, mode: post.map['mode'])
  if !player_md.empty?
    md += "\n#{player_md}"
  else
    log('Player markdown response was empty')
  end
  gh_url = 'https://github.com/christopher-dG/osu-bot'
  dev_url = 'https://reddit.com/u/PM_ME_DOG_PICS_PLS'
  md += "\n***\n\n"
  md += "^(I'm a bot. )[^Source](#{gh_url})^( | )[^Developer](#{dev_url})"
  DEBUG && log("Generated full comment:\n#{md}")
  return md
end

# Get a Markdown string for a player's top ranked play.
def top_play(player, mode)
  DEBUG && log("Generating Markdown for top play of #{player['username']} (mode=#{mode})")
  # Todo: clean this up.
  begin
    play = request('user_best', u: player['user_id'], t: 'id', m: mode)
  rescue
    log('Request failed for player\'s top play')
    return nil
  end
  id = play['beatmap_id']
  begin
    map = request('beatmaps', b: id)
  rescue
    log('Request failed for map of top play')
    return nil
  # begin
  #   score = request('scores', b: id, u: p_id, t: 'id', m: mode)
  # rescue
  #   log('Request failed for player\'s score on top play')
  # end
  end

  mods = mods_from_int(play['enabled_mods'])
  mods = mods.empty? ? '' : "+#{mods.join}"
  combo = play['perfect'] == '1' ? '' : "(#{play['maxcombo']}/#{map['max_combo']}) "
  md = "[#{map_string(map)}](#{OSU_URL}/b/#{id}) #{mods} "
  md += "#{play['countmiss'] == '0' ? 'FC ' : ''}#{BAR} "
  md += "#{accuracy(play)}% #{combo}#{BAR} #{format_num(round(play['pp']))}pp"
  DEBUG && log("Generated:\n#{md}")
  return md
end

# Generate a Markdown string with player information. Return empty string upon failure.
def player_markdown(player, mode: '0')
  DEBUG && log("Generating player Markdown for '#{player['username']}'")
  begin
    top_md = top_play(player, mode)
    id = player['user_id']
    headers = ['Player', 'Rank', 'pp', 'Acc', 'Playcount']
    cols = [
      ["[#{player['username']}](#{OSU_URL}/u/#{id})"],
      ["\##{format_num(player['pp_rank'])}"],
      [format_num(round(player['pp_raw']))],
      ["#{round(player['accuracy'], 2)}%"],
      [format_num(player['playcount'])],
    ]
  rescue
    log("Generating player Markdown failed for '#{player['username']}'")
    return ''
  end

  if !top_md.nil?
    headers += ['Top Play']
    cols += [[top_md]]
  end
  DEBUG && log('Generating table for player')
  return table(headers, cols)
end

# Generate a Markdown table. headers and cols are one and two dimensional
# arrays, respectively. Pass align: 'l' for left alignment and 'r' for right
# alignment, otherwise cells will be centered. The data must represent a full
# table, i.e. all cols must be the same length and there must be the same number
# of cols as there are headers.
# table({"a"=>[1, 2], "b"=>[3, 4], "c"=>[5, 6]}) => "a|b|c\n:-:|:-:|:-:\n1|3|5\n2|4|6"
def table(headers, cols, align: '')
  DEBUG && log("Creating table.\nheaders: #{headers}\ncols: #{cols}")
  # Sanity checks.
  error = headers.empty? || cols.empty? || cols.all? {|r| r.empty?} ||
          cols.any? {|r| r.length != cols[0].length}
  error && DEBUG && log('Sanity checks failed')

  table = "#{headers.join('|')}\n"
  sep = align == 'l' ? ':-' : align == 'r' ? '-:' : ':-:'
  table += "#{([sep] * headers.length).join('|')}\n"
  (0...cols[0].length).each do |i|
    row = ''
    cols.each {|c| row += "#{c[i]}|"}
    row = row[0...-1]  # Remove trailing '|'.
    DEBUG && log("Row: #{row}")
    table += "#{row}"
  end
  DEBUG && log("Generated table:\n#{table}")
  return table
end

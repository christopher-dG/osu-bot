# Generate a markdown string with beatmap information.
def beatmap_md(map, mods)
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

# Generate a Markdown string to be commented.
# `mode` = game mode: 0 => standard, 1 => taiko, 2 => catch, 3 => mania.
def comment(map, player, mods, mode: '0')
  text = gen_beatmap_md(map, mods)
  player_md = gen_player_md(player, mode: mode)
  player_md != nil && text += player_md

  gh_url = 'https://github.com/christopher-dG/osu-bot'
  dev_url = 'https://reddit.com/u/PM_ME_DOG_PICS_PLS'
  text += "***\n\n"
  text += "^(I'm a bot. )[^Source](#{gh_url})^( | )[^Developer](#{dev_url})"

  return text
end

# Generate a Markdown string with player information.
def player_md(player, mode: '0')
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

# Generate a Markdown table.
# Data is a hash with keys as headers and lists to fill the cells.
# table({"a"=>[1, 2], "b"=>[3, 4], "c"=>[5, 6]}) => "a|b|c\n:-:|:-:|:-:\n1|3|5\n2|4|6"
def table(data, align: 'c')
  row_i = Proc.new do |i|
    row = []
    data.keys.each {|k| row.push(data[k][i])}
    row
  end

  text = "#{data.keys.join('|')}\n"
  sep = align == 'l' ? ':-' : align == 'r' ? '-:' : ':-:'
  text += "#{([sep] * data.keys.length).join('|')}\n"
  for r in 0..data.keys[0].length
    text += "#{row_i.call(r).join('|')}\n"
  end
  return text.chomp
end

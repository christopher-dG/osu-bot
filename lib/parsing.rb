# Criteria for a post to be commented on.Title matching is deliberately
# lenient because false positives are more of a problem then false negatives.
def should_comment(post)
  is_score = post.title =~ /.*\|.*-.*\[.*\].*/ && !post.is_self
  log("Post is #{is_score ? '' : 'not '}a score post")
  if is_score && DRY
    return true
  elsif !is_score
    return false
  end
  commented = post.comments.any? {|c| c.author.name == 'osu-bot'}
  log("Post has #{commented ? 'already' : 'not'} been commented on")
  return !commented
end

# Split a title into relevant pieces: player, song, and diff names.
def split_title(title)
  log("Splitting title '#{title}'")
  player, map = title.split('|', 2)
  player_name = player.match(/[\w\-\[\]][ \w\-\[\]]+[\w\-\[\]]/).to_s
  song_name = map[0...map.rindex('[')].strip  # Artist - Title
  diff_name = map[map.rindex('[') + 1...map.rindex(']')].strip
  log("player: '#{player_name}', song: '#{song_name}', diff: '#{diff_name}'")
  return player_name, song_name, diff_name
end

# Get the enabled mods from an integer.
# https://github.com/ppy/osu-api/wiki#mods
# Returns '+Mod1Mod2Mod3' or an empty string.
def mods_from_int(mods)
  log("Parsing mods from integer: #{mods}")
  i = mods.to_i
  mod_list = []
  BITWISE_MODS.keys.reverse.each do |mod|
    if i == 0 && !mod_list.empty?
      mod_list.include?('NC') && mod_list.delete('DT')
      # Set the order.
      MODS.each {|m| mod_list.delete(m) && mod_list.push(m)}
      log("Mods: #{mod_list}")
      return mod_list
    elsif mod <= i
      mod_list.push(BITWISE_MODS[mod])
      i -= mod
    end
  end
  log('Did not find mods')
  return ''
end

# Get a modstring from a post title.
# Returns an array of mods or an empty string if mods are not found.
def mods_from_string(title)
  log("Getting mods from string: '#{title}'")
  title = title.upcase

  is_mods = Proc.new {|list| list.all? {|m| MODS.include?(m)}}
  map = title.split('|', 2)[1]
  plus = map.index('+', map.index(']'))

  # If there's a '+' in the title somewhere after the diff name, try to parse
  # the mods from the text immediately following it.
  if !plus.nil?
    string = map[plus..-1]
    string = string.match(/[[A-Z],]+/).to_s
    list = string.include?(',') ? string.split(',') : string.scan(/[A-Z]{1,2}/)
    if is_mods.call(list)
      MODS.each {|m| list.delete(m) && list.push(m)}
      log("Mods: #{list}")
      return list
    end
  end

  tokens = map[map.index(']')..-1].split
  tokens.each do |token|
    list = token.gsub(',', '').scan(/[A-z]{1,2}/)
    if is_mods.call(list)
      MODS.each {|m| list.delete(m) && list.push(m)}
      log("Mods: #{list}")
      return list
    end
  end
  log('Did not find mods.')
  return ''
end

# Get difficulty values (not pp!) for a map with and without some given mods.
# Returns a hash in the form: {'property' => ['nomod', 'modded']}. If there are
#   no mods or the mods do not affect the difficulty, values are length-one arrays.
def diff_vals(map, mods)
  log("Getting diff values from #{map_string(map)} with mods '+#{mods.join}'")
  nomod = {
    'CS' => [map['diff_size']],
    'AR' => [map['diff_approach']],
    'OD' => [map['diff_overall']],
    'HP' => [map['diff_drain']],
    'SR' => [round(map['difficultyrating'], 2)],
  }
  log("Nomod values: #{nomod}")

  modded = !mods.empty? ? oppai(map['beatmap_id'], mods: mods, mode: 'diff') : nil
  log("Modded values from oppai: #{modded}")

  # If the mods won't change the values: don't return the mod
  if modded.nil? || mods.all? {|m| NO_DIFF_MODS.include?(m)}
    log('Mods were empty or ignored, returning nomod values')
    return nomod
  end

  ez_hp_scalar = 0.5
  hr_hp_scalar = 1.4
  hp_max = 10

  # Oppai does not handle HP drain.
  if mods.include?('EZ')
    m_hp = round(nomod['HP'][0].to_f * ez_hp_scalar, 2)
  elsif mods.include?('HR')
    m_hp = round(nomod['HP'][0].to_f * hr_hp_scalar, 2)
    m_hp = m_hp.to_f > hp_max ? 10 : m_hp
  else
    m_hp = nomod['HP'][0]
  end

  log("Manually calculated HP value: #{m_hp}")
  vals = {
    'CS' => [nomod['CS'][0], modded['CS']], 'AR' => [nomod['AR'][0], modded['AR']],
    'OD' => [nomod['OD'][0], modded['OD']], 'HP' => [nomod['HP'][0], m_hp],
    'SR' => [nomod['SR'][0], modded['SR']]
  }
  log("Final diff values: #{vals}")
  return vals
end

# Get tthe ranked status of a beatmap.
def ranked_status(map)
  log("Getting ranked status for '#{map_string(map)}")
  # '2' => 'Approved' but that's equivalent to 'Ranked'.
  approvals = {'1' => 'Ranked', '2' => 'Ranked', '3' => 'Qualified', '4' => 'Loved'}
  if approvals.key?(map['approved'])
    status = "#{approvals[map['approved']]} (#{map['approved_date'][0..9]})"
    log("Ranked status: #{status}")
    return status
  else
    log('Ranked status: Unranked')
    return 'Unranked'
  end
end

# Get adjusted  BPM and length values for HT/DT/NC.
# Length is the number of seconds as either an int or string.
# Returns [adjusted bpm, adjusted length_seconds] as strings.
def adjusted_timing(bpm, length, mods)
  log("Getting adjusted timing, bpm: #{bpm}, length: #{length}, mods: +#{mods.join}")
  bpm, length = bpm.to_i, length.to_i
  adj_bpm, adj_length = bpm, length
  if ['DT', 'NC'].any? {|m| mods.include?(m)}
    adj_bpm = round(bpm * 1.5)
    adj_length = round(length * 0.66)
  elsif mods.include?('HT')
    adj_bpm = round(bpm * 0.66)
    adj_length = round(length * 1.5)
  end
  log("Adjusted bpm, length: #{adj_bpm}, #{adj_length}")
  return adj_bpm, adj_length
end

# Get a score's percentage accuracy as a string.
def accuracy(score)
  log('Getting accuracy')
  c = {
    300 => score['count300'].to_i, 100 => score['count100'].to_i,
    50 => score['count50'].to_i, 0 => score['countmiss'].to_i
  }
  o = c.values.sum.to_f  # Total objects.
  acc = "#{round([c[300] / o, c[100] / o * 1/3.to_f, c[50] / o * 1/6.to_f].sum * 100, 2, force: true)}"
  log("Accuracy: #{acc}")
  return acc
end

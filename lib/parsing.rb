# Criteria for a post to be commented on.Title matching is deliberately
# lenient because false positives are more of a problem then false negatives.
def should_comment(post)
  DEBUG && log("Checking if '#{post.title}' is a score post")
  is_score = post.title =~ /.*\|.*-.*\[.*\].*/ && !post.is_self &&
             (DRY || !post.comments.any? {|c| c.author.name == 'osu-bot'})
  DEBUG && log("Post is #{is_score ? '' : 'not '}a score post")
  return is_score
end

# Split a title into relevant pieces: player, song, and diff names.
def split_title(title)
  DEBUG && log("Splitting title '#{title}'")
  player, map = title.split('|', 2)
  player_name = player.match(/[\w\-\[\]][ \w\-\[\]]+[\w\-\[\]]/).to_s
  song_name = map[0...map.rindex('[')].strip  # Artist - Title
  diff_name = map[map.rindex('[') + 1...map.rindex(']')].strip
  DEBUG && log("player: '#{player_name}', song: '#{song_name}', diff: '#{diff_name}'")
  return player_name, song_name, diff_name
end

# Get the enabled mods from an integer.
# https://github.com/ppy/osu-api/wiki#mods
# Returns '+Mod1Mod2Mod3' or an empty string.
def mods_from_int(mods)
  DEBUG && log("Parsing mods from integer: #{mods}")
  i = mods.to_i
  mod_list = []
  BITWISE_MODS.keys.reverse.each do |mod|
    if i == 0 && !mod_list.empty?
      mod_list.include?('NC') && mod_list.delete('DT')
      # Set the order.
      MODS.each {|m| mod_list.delete(m) && mod_list.push(m)}
      DEBUG && log("Mods: #{mods}")
      return mod_list
    elsif mod <= i
      mod_list.push(BITWISE_MODS[mod])
      i -= mod
    end
  end
  DEBUG && log('Did not find mods')
  return ''
end

# Get a modstring from a post title.
# Returns an array of mods or an empty string if mods are not found.
def mods_from_string(title)
  DEBUG && log("Getting mods from string: '#{title}'")
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
      DEBUG && log("Mods: #{list}")
      return list
    end
  end

  tokens = map[map.index(']')..-1].split
  tokens.each do |token|
    list = token.gsub(',', '').scan(/[A-z]{1,2}/)
    if is_mods.call(list)
      MODS.each {|m| list.delete(m) && list.push(m)}
      DEBUG && log("Mods: #{list}")
      return list
    end
  end
  DEBUG && log('Did not find mods.')
  return ''
end

# Get difficulty values (not pp!) for a map with and without some given mods.
# Returns a hash in the form: {'property' => ['nomod', 'modded']}. If there are
#   no mods or the mods do not affect the difficulty, values are length-one arrays.
def diff_vals(map, mods)
  DEBUG && log("Getting diff values from #{map_string(map)} with mods '+#{mods.join}'")
  nomod = {
    'CS' => [map['diff_size']],
    'AR' => [map['diff_approach']],
    'OD' => [map['diff_overall']],
    'HP' => [map['diff_drain']],
    'SR' => [round(map['difficultyrating'], 2)],
  }
  DEBUG && log("Nomod values: #{nomod}")

  modded = !mods.empty? ? oppai(map['beatmap_id'], mods: mods, mode: 'diff') : nil
  DEBUG && log("Modded values from oppai: #{modded}")

  # If the mods won't change the values: don't return the mod
  if modded.nil? || mods.all? {|m| NO_DIFF_MODS.include?(m)}
    DEBUG && log('Mods were empty or ignored, returning nomod values')
    return nomod
  end

  ez_hp_scalar = 0.5
  hr_hp_scalar = 1.4
  hp_max = 10

  # Oppai does not handle HP drain.
  if mods.include?('EZ')
    m_hp = round(nomod['HP'][0].to_f * ez_hp_scalar), 2
    m_hp = m_hp.to_i == m_hp ? m_hp.to_i.to_s : m_hp.to_s
  elsif mods.include?('HR')
    m_hp = round(nomod['HP'][0].to_f * hr_hp_scalar, 2)
    m_hp = m_hp.to_f > hp_max ?
             hp_max.to_s : m_hp.to_i == m_hp ? m_hp.to_i.to_s : m_hp.to_s
  else
    m_hp = nomod['HP'][0]
  end

  DEBUG && log("Manually calculated HP value: #{m_hp}")
  vals = {
    'CS' => [nomod['CS'][0], modded['CS']], 'AR' => [nomod['AR'][0], modded['AR']],
    'OD' => [nomod['OD'][0], modded['OD']], 'HP' => [nomod['HP'][0], modded['HP']],
    'SR' => [nomod['SR'][0], modded['SR']]
  }
  DEBUG && log("Final diff values: #{vals}")
  return vals
end

# Get tthe ranked status of a beatmap.
def ranked_status(map)
  DEBUG && log("Getting ranked status for '#{map_string(map)}")
  # '2' => 'Approved' but that's equivalent to 'Ranked'.
  approvals = {'1' => 'Ranked', '2' => 'Ranked', '3' => 'Qualified', '4' => 'Loved'}
  if approvals.key?(map['approved'])
    status = "#{approvals[map['approved']]} (#{map['approved_date'][0..9]})"
    DEBUG && log("Ranked status: #{status}")
    return status
  else
    DEBUG && log('Ranked status: Unranked')
    return 'Unranked'
  end
end

# Get adjusted  BPM and length values for HT/DT/NC.
# Length is the number of seconds as either an int or string.
# Returns [adjusted bpm, adjusted length_seconds] as strings.
def adjusted_timing(bpm, length, mods)
  DEBUG && log("Getting adjusted timing, bpm: #{bpm}, length: #{length}, mods: +#{mods.join}")
  bpm, length = bpm.to_i, length.to_i
  adj_bpm, adj_length = bpm, length
  if mods =~ /DT|NC/
    adj_bpm = round(bpm * 1.5, 2)
    adj_length =round(length * 0.66)
  elsif mods =~ /HT/
    adj_bpm = round(bpm * 0.66)
    adj_length = round(length * 1.5)
  end
  DEBUG && log("Adjusted bpm, length: #{adj_bpm}, #{adj_length}")
  return adj_bpm, adj_length
end

# Get a score's percentage accuracy as a string.
def accuracy(score)
  DEBUG && log('Getting accuracy')
  c = {
    300 => score['count300'].to_i, 100 => score['count100'].to_i,
    50 => score['count50'].to_i, 0 => score['countmiss'].to_i
  }
  o = c.values.sum.to_f  # Total objects.
  acc = round([c[300] / o, c[100] / o * 1/3.to_f, c[50] / o * 1/6.to_f].sum * 100, 2)
  DEBUG && log("Accuracy: #{acc}")
  return acc
end

# Get pp data from oppai for the map stored in 'map.osu' with some given mods.
def oppai_pp(mods, nomod_vals: [])
  DEBUG && log("Getting pp from oppai for mods +#{mods.join} with nomod values: #{nomod_vals}")
  if !nomod_vals.empty? && mod_list.all? {|m| NO_PP_MODS.include?(m)}
    # If the mods won't change the pp values, return the nomod value.
    DEBUG && log('Mods  don\'t change  pp, returning nomod values')
    return nomod_vals
  elsif mods.any? {|m| ZERO_PP_MODS.include?(m)}
    # If any of the mods cancel out pp, return zeros.
    DEBUG && log('Mods give no pp, returning zeroed values')
    return [0] * 4
  end

  result = []
  begin
    modstring = !mods.empty? ? "+#{mods.join}" : ''
    ['95%', '98%', '99%', '100%'].each do |acc|
      DEBUG && log("Running command \`#{OPPAI} map.osu #{acc} +#{mods.join}\`")
      pp = round(`#{OPPAI} map.osu #{acc} #{mostring}`.split("\n")[-1][0..-3])
      DEBUG && log("pp result from oppai: #{pp}")
      $? != 0 && raise
      result.push(format_num(pp))
    end
  rescue
    log('Modded pp calculations failed.')
    return nil
  end

  DEBUG && log("Modded pp: #{result}")
  return result
end

# Get difficulty values from oppai for the map stored in 'map.osu'.
# Returns a hash with keys for each  difficulty property, or nil.
def oppai_diff(mods)
  DEBUG && log("Getting diff values from oppai for mods +#{mods.join}")
  begin
    result = `#{OPPAI} map.osu #{mods}`.split("\n")
  rescue
    log('Modded diff value calculations failed.')
    return nil
  end

  parse = Proc.new do |target, text|
    val = /#{target}[0-9]{1,2}(\.[0-9]{1,2})?/.match(text).to_s[2..-1].to_f
    val.to_i == val ? val.to_i : val
  end

  diff = {}
  result.each do |r|
    if ['od', 'ar', 'cs'].all? {|v| result.include?(v)}
      diff = {
        'CS' => parse.call('cs', r),
        'AR' => parse.call('ar', r),
        'OD' => parse.call('od', r),
      }
      break
    end
  end

  result.each do |r|
    match = r.match(/[0-9]+(\.[0-9]+)? stars/).to_s
    if !match.empty?
      diff['SR'] = match[0...match.index(' ')]
      break
    end
  end
  DEBUG && log("Modded diff values: #{diff}")
  return diff
end

# Download a file and analyze it with the given acc and mods  via oppai.
# Returns a hash with relevant information.
# If mode = 'pp', get pp data. If mode = 'diff', get diff values.
# nomod_vals is a list of previously computed nomod pp values.
def oppai(map_id, mode:, mods: [], nomod_vals: [])
  msg = "Running oppai in #{mode} mode for map_id '#{map_id}'"
  msg += "and mods '+#{mods.join}' with nomod values: #{nomod_vals}"
  DEBUG && log(msg)
  begin
    url = "#{OSU_URL}/osu/#{map_id}"
    DEBUG && log("Downloading map from #{url}")
    File.open('map.osu', 'w') do |f|
      f.write(HTTParty.get(url).parsed_response)
    end
    DEBUG && log('Wrote map to map.osu')
  rescue
    log("Downloading beatmap failed for '#{map_id}'")
    return nil
  end

  begin
    result = nil
    if mode == 'pp'
      result = oppai_pp(mods, nomod_vals: nomod_vals)
    elsif mode == 'diff'
      result = oppai_diff(mods)
    end
  rescue
    FileUtils.cp('map.osu', "#{File.dirname(LOG)}/maps/#{map_id}.osu")
    log("oppai failed in '#{mode}' mode: saved map to logs/maps/#{map_id}.osu")
    return nil
  ensure
    DEBUG && log('Deleting map.osu')
    File.file?('map.osu') && File.delete('map.osu')
  end

  DEBUG && log("oppai final result: #{result}")
  return result
end

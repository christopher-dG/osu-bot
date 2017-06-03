# coding: utf-8

# Criteria for a post to be commented on.Title matching is deliberately
# lenient because false positives are more of a problem then false negatives.
def should_comment(post)
  is_score = post.title =~ /.+\|.+-.+\[.+\].*/ && !post.is_self
  log("Post is #{is_score ? '' : 'not '}a score post")

  # If we're doing a dry run, don't check if we've commented or not.
  if DRY
    return is_score
  end

  if is_score
    commented = post.comments.any? {|c| c.author.name == 'osu-bot'}
    log("Post has #{commented ? 'already' : 'not'} been commented on")
    return !commented
  else
    return false
  end
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

# Remove mods that we don't care about.
def prune_mods(mods)
  log('Pruning mods')
  IGNORE_MODS.each {|m| mods.delete(m)}
  log("Remaining mods: #{mods}")
  return mods
end

# Get an array of mods from a post title.
def mods_from_string(title)
  log("Getting mods from string: '#{title}'")
  text = title[title.index(']', title.index('|')) + 1..-1].upcase

  is_mods = Proc.new {|list| !list.empty? && list.all? {|m| MODS.include?(m)}}
  plus = text.index('+')

  # If there's a '+' in the title somewhere after the diff name, try to parse
  # the mods from the text immediately following it.
  if !plus.nil?
    string = text[plus..-1]
    string = string.match(/[[A-Z],]+/).to_s
    list = string.include?(',') ? string.split(',') : string.scan(/[A-Z]{1,2}/)
    if is_mods.call(list)
      MODS.each {|m| list.delete(m) && list.push(m)}
      log("Mods: #{list}")
      return prune_mods(list)
    end
  end

  tokens = text.split
  tokens.each do |token|
    list = token.gsub(',', '').scan(/[A-z]{1,2}/)
    if is_mods.call(list)
      # Set the order.
      MODS.each {|m| list.delete(m) && list.push(m)}
      log("Mods: #{list}")
      return prune_mods(list)
    end
  end
  log('Did not find mods.')
  return []
end

# Get the enabled mods from an integer as an array
# https://github.com/ppy/osu-api/wiki#mods
def mods_from_int(mods)
  log("Parsing mods from integer: #{mods}")
  i = mods.to_i
  mod_list = []
  BITWISE_MODS.keys.reverse.each do |mod|
    if i == 0 && !mod_list.empty?
      # NC and PF are variations of other existing mods which
      # are also applied, but should not be displayed.
      mod_list.include?('NC') && mod_list.delete('DT')
      mod_list.include?('PF') && mod_list.delete('SD')
      # Set the order.
      MODS.each {|m| mod_list.delete(m) && mod_list.push(m)}
      log("Mods: #{mod_list}")
      return prune_mods(mod_list)
    elsif mod <= i
      mod_list.push(BITWISE_MODS[mod])
      i -= mod
    end
  end
  log('Did not find mods')
  return []
end

# Convert an array of mods to an integer as a string.
# https://github.com/ppy/osu-api/wiki#mods
def mods_to_int(mods)
  sum = 0
  mods.each do |m|
    sum += BITWISE_MODS.key(m)
    # Need to manually add DT if we find NC.
    m == 'NC' && sum += BITWISE_MODS.key('DT')
  end
  return sum.to_s
end

# Get difficulty values (not pp!) for a map with and without some given mods.
# Returns a hash in the form: {'property' => ['nomod', 'modded']}. If there are
# no mods or the mods do not affect the difficulty, values are length-one arrays.
def diff_vals(map, mods)
  log("Getting diff values from #{map_string(map)} with mods '+#{mods.join}'")
  # vals follows the format: {property => [nomod, modded]}.
  vals = {
    'CS' => [map['diff_size']],
    'AR' => [map['diff_approach']],
    'OD' => [map['diff_overall']],
    'HP' => [map['diff_drain']],
    'SR' => [round(map['difficultyrating'], 2)],
  }
  log("Nomod values: #{vals}")

  # If the mods don't affect difficulty values, we don't need to use oppai.
  # In the case of zero-effect mods like PF, we don't even need to display them.
  # In the case of HD, pp values are affected so we'll just display the nomod
  # difficulty values twice. Non-standard game modes can't be calculated.

  if map['mode'] != '0' || mods.all? {|m| SAME_PP_MODS.include?(m)}
    log('Only using nomod values')
    return vals
  elsif mods.all? {|m| SAME_DIFF_MODS.include?(m)}
    log('Reusing nomod values')
    vals.keys.each {|k| vals[k] *= 2}
    return vals
  end

  # If we reach this point, we calculate and display modded values.
  begin
    modded = oppai(map['beatmap_id'], mods: mods, mode: 'diff')
  rescue
    # Something went wrong with calculation, so we'll just display nomod.
    log('Returning nomod values')
    return vals
  else
    modded.keys.each {|k| vals[k].push(modded[k])}
  end

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
  bpm, length = bpm.to_f, length.to_f
  adj_bpm, adj_length = bpm, length
  dt_scalar, ht_scalar = 1.5, 0.75
  if ['DT', 'NC'].any? {|m| mods.include?(m)}
    adj_bpm = round(bpm * dt_scalar)
    adj_length = round(length / dt_scalar)
  elsif mods.include?('HT')
    adj_bpm = round(bpm * ht_scalar)
    adj_length = round(length / ht_scalar)
  end
  log("Adjusted bpm, length: #{adj_bpm}, #{adj_length}")
  return round(adj_bpm, 1), round(adj_length, 1)
end

# Get a score's percentage accuracy as a string.
# Todo: find out how this behaves with non-standard game modes.
def accuracy(score)
  log('Getting accuracy')
  c = {
    300 => score['count300'].to_i, 100 => score['count100'].to_i,
    50 => score['count50'].to_i, 0 => score['countmiss'].to_i
  }
  o = c.values.sum.to_f  # Total objects.
  acc = [c[300] / o, c[100] / o * 1/3.to_f, c[50] / o * 1/6.to_f].sum * 100
  acc = round(acc, 2)
  log("Accuracy: #{acc}")
  return acc
end

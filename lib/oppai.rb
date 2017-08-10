# coding: utf-8

# Download a beatmap with a given id. Anything using this function should do
# its own error handling.
def download_map(map_id)
  url = "#{OSU_URL}/osu/#{map_id}"
  log("Downloading map from #{url}")
  File.open('map.osu', 'w') do |f|
    f.write(HTTParty.get(url).parsed_response)
  end
  log('Wrote map to \'map.osu\'')
  return true
end

# Generate a command to run oppai on 'map.osu' with given mods and acc.
def cmd(mods:, acc: '')
  acc = acc.empty? ? '' : "#{acc}% "
  log("Constructing oppai command for mods: #{mods}, acc: #{acc}")
  cmd = "oppai map.osu -ojson #{acc}"
  cmd += "+#{mods.join}" if !mods.empty?
  log("Command: #{cmd}")
  return cmd
end

# Get pp data from oppai for the map stored in 'map.osu' with some given mods.
# Returns a list of pp values.
def oppai_pp(map_id, acc, mods, nomod_vals: [])
  log("Getting pp from oppai for mods +#{mods.join} with nomod values: #{nomod_vals}")

  if !nomod_vals.empty? && mods.all? {|m| SAME_PP_MODS.include?(m)}
    # If the mods won't change the pp values, return the nomod value.
    log("Mods  don't change  pp, returning nomod value")
    return nomod_vals
  end

  result = []
  accs = [95, 98, 99, 100]
  accs.push(acc) if !accs.any? {|a| a == acc.to_f} && !acc.empty?
  accs.sort_by(&:to_f).each do |acc|
    begin
      pp = JSON.parse(`#{cmd(mods: mods, acc: acc.to_s)}`)['pp']
    rescue
      log('Something went wrong with oppai')
      raise
    end
    log("pp result from oppai: #{pp}")
    result.push(format_num(pp))
  end

  log("pp: #{result}")
  return result
end

# Get difficulty values from oppai for the map stored in 'map.osu'.
# Returns a hash with keys for each difficulty property.
def oppai_diff(map_id, mods)
  log("Getting diff values from oppai for mods +#{mods.join}")
  begin
    result = JSON.parse(`#{cmd(mods: mods)}`)
  rescue
    log('Modded diff value calculations failed.')
    raise
  end

  diff = {
    'CS' => round(result['cs'], 1),
    'AR' => round(result['ar'], 1),
    'OD' => round(result['od'], 1),
    'HP' => round(result['hp'], 1),
    'SR' => round(result['stars'], 2),
  }
  log("Diff values: #{diff}")
  return diff
end

# Download a file and analyze it with the given acc and mods via oppai.
# Returns a hash with relevant information.
# If mode = 'pp', get pp data. If mode = 'diff', get diff values.
# nomod_vals is a list of previously computed nomod pp values.
# acc is a number in string form.
def oppai(map_id, mode:, mods: [], nomod_vals: [], acc: '')
  begin
    download_map(map_id)
  rescue
    log("Downloading beatmap failed for '#{map_id}'")
    raise
  end

  msg = "Running oppai in '#{mode}' mode for map_id '#{map_id}'"
  msg += "and mods '+#{mods.join}' with nomod values: #{nomod_vals}"
  log(msg)

  result = ''
  begin
    if mode == 'pp'
      result = oppai_pp(map_id, acc, mods, nomod_vals: nomod_vals)
    elsif mode == 'diff'
      result = oppai_diff(map_id, mods)
    end
  rescue
    FileUtils.cp('map.osu', "#{File.dirname(LOG)}/maps/#{map_id}.osu")
    log("oppai failed in '#{mode}' mode: saved map to logs/maps/#{map_id}.osu")
    raise
  ensure
    # Todo: Don't redownload the same map for each call to oppai.
    # Could save to $map_id.osu and delete all .osu files afterwards, or even
    # cache map files for reuse across runs.
    log('Deleting map.osu')
    File.delete('map.osu') if File.file?('map.osu')
  end

  log("oppai final result: #{result}")
  return result
end

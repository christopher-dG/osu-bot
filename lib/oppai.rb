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
  acc = acc.empty? ? '' : "#{acc}%"
  log("Constructing oppai command for mods: #{mods}, acc: #{acc}")
  cmd = "#{OPPAI} map.osu #{acc}"
  !mods.empty? &&  cmd += " +#{mods.join}"
  log("Command: #{cmd}")
  return cmd
end

# Get pp data from oppai for the map stored in 'map.osu' with some given mods.
def oppai_pp(map_id, acc, mods, nomod_vals: [])
  log("Getting pp from oppai for mods +#{mods.join} with nomod values: #{nomod_vals}")
  if !nomod_vals.empty? && mods.all? {|m| NO_PP_MODS.include?(m)}
    # If the mods won't change the pp values, return the nomod value.
    log('Mods  don\'t change  pp, returning nomod value')
    return nomod_vals
  elsif mods.any? {|m| ZERO_PP_MODS.include?(m)}
    # If any of the mods cancel out pp, return zeros.
    log('Mods give no pp, returning zeroed values')
    return [0] * 4
  end

  result = []
  begin
    %W(95 98 99 100 #{acc}).sort_by(&:to_i).each do |acc|
      pp = round(`#{cmd(mods: mods, acc: acc)}`.split("\n")[-1].match(/[^ p]+/).to_s)
      $? != 0 && raise
      log("pp result from oppai: #{pp}")
      result.push(format_num(pp))
    end
  rescue
    log('Modded pp calculations failed.')
    return nil
  end

  log("Modded pp: #{result}")
  return result
end

# Get difficulty values from oppai for the map stored in 'map.osu'.
# Returns a hash with keys for each  difficulty property, or nil.
def oppai_diff(map_id, mods)
  log("Getting diff values from oppai for mods +#{mods.join}")
  begin
    result = `#{cmd(mods: mods)}`.split("\n")
  rescue
    log('Modded diff value calculations failed.')
    return nil
  end

  # Magic numbers. Review this if oppai ever gets updated.
  diff_line = 12
  star_line = 19
  diff = {
    'CS' => round(result[diff_line].match(/cs[^ ]+/).to_s[2..-1], 1),
    'AR' => round(result[diff_line].match(/ar[^ ]+/).to_s[2..-1], 1),
    'OD' => round(result[diff_line].match(/od[^ ]+/).to_s[2..-1], 1),
    'SR' => round(result[star_line].match(/[^ ]+/).to_s, 2),
  }
  log("Modded diff values: #{diff}")
  return diff
end

# Download a file and analyze it with the given acc and mods  via oppai.
# Returns a hash with relevant information.
# If mode = 'pp', get pp data. If mode = 'diff', get diff values.
# nomod_vals is a list of previously computed nomod pp values.
def oppai(map_id, mode:, mods: [], nomod_vals: [], acc: '')
  begin
    download_map(map_id)
  rescue
    log("Downloading beatmap failed for '#{map_id}'")
    return nil
  end
  begin
    msg = "Running oppai in '#{mode}' mode for map_id '#{map_id}'"
    msg += "and mods '+#{mods.join}' with nomod values: #{nomod_vals}"
    log(msg)

    result = ''
    if mode == 'pp'
      result = oppai_pp(map_id, acc, mods, nomod_vals: nomod_vals)
    elsif mode == 'diff'
      result = oppai_diff(map_id, mods)
    end
  rescue
    FileUtils.cp('map.osu', "#{File.dirname(LOG)}/maps/#{map_id}.osu")
    log("oppai failed in '#{mode}' mode: saved map to logs/maps/#{map_id}.osu")
    return nil
  ensure
    log('Deleting map.osu')
    File.file?('map.osu') && File.delete('map.osu')
  end

  log("oppai final result: #{result}")
  return result
end

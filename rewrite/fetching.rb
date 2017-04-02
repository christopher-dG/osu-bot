# Get a beatmap matching `map_name` from a `player`.
# https://github.com/ppy/osu-api/wiki#beatmap
def beatmap_from_player(player, map_name)
  map_id = -1
  player['events'].each do |e|
    if bleach(e['display_html']).include?(bleach(map_name))
      map_id = e['beatmap_id']
      break
    end
    return request('beatmaps', {'b' => map_id})
  end
end

# Download a file and analyze it with the given acc and mods  via oppai.
# Returns a hash with relevant information.
def oppai_analyze(map_id, acc: '', mods: '')
  result = nil
  begin
    File.open('map.osu', 'w') do |f|
      f.write(HTTParty.get("#{URL}/osu/#{map_id}").parsed_response)
    end
  rescue
    File.file?('map.osu') && File.delete('map.osu')
    # Todo: Logging.
  end

  if result == nil
    return nil
  end

  if acc.empty?  # Getting difficulty data.
    result = `#{OPPAI} map.osu #{mods}`.split("\n")
    values = result[12]
    stars = result[19][0...result[19].index(' ')]
    parse = Proc.new do |target, text|
      val = /#{target}[0-9]{1,2}(\.[0-9]{1,2})?/.match(text).to_s[2..-1].to_f
      val.to_i == val ? val.to_i : val
    end
    result = {
      'od' => parse.call('od', values), 'ar' => parse.call('ar', values),
      'cs' => parse.call('cs', values), 'sr' => stars
    }

  else  # Getting pp data.
    result = {}
    ['95%', '98%', '99%', '100%'].each do |acc|
      result[acc[0...-1]] = `#{OPPAI} map.osu #{acc} #{mods}`.
                              split("\n")[-1][0..-3].to_f.round(0)
      $? != 0 && raise
    end
  end
  return result
end

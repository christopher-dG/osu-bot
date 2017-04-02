class ScorePost
  attr_accessor :player
  attr_accessor :song
  attr_accessor :diff
  attr_accessor :mods
  def initialize(title)
    player_name, song_name, diff_name = split_title(title)
    player = request('user', {'u' => player_name, 'type' => 'id'})
    @player = player  # Hash: https://github.com/ppy/osu-api/wiki#user
    @map = beatmap_from_player(player)  # Hash: https://github.com/ppy/osu-api/wiki#beatmap
    @diff = diff_name  # String
    @mods = mods_from_string(title)  # String: '+Mod1Mod2Mod3'
    @title = "#{song_name} - [#{diff_name}]"
  end
end


def search(title, test_set: {})
  begin
    player_name, song, diff = split_title(title)
    full_name = "#{song} [#{diff}]".gsub('&', '&amp;')  # Artist - Title [Diff Name]

    if test_set.empty?
      player = request('user', {'u' => player_name, 'type' => 'string'})
      events = player['events']
    else
      player = test_set['player']
      events = player['events']
    end

    # Use the player's recent events. Score posts are likely to be at least top
    # 50 on the map, and this method takes less time than looking through recents.
    map_id = -1
    for event in events
      if event['display_html'].downcase.include?(full_name.downcase)
        map_id = event['beatmap_id']
        break
      end
    end

    if map_id == -1  # Use player's recent plays as a backup. This takes significantly longer.
      seen_ids = []  # Avoid making duplicate API calls.
      t = Time.now  # Log how long this takes.
      for play in request('user_recent', {'u' => player['user_id'], 'type' => 'id'})
        seen_ids.include?(play['beatmap_id']) && next
        seen_ids.push(play['beatmap_id'])

        id = play['beatmap_id']
        btmp = request('beatmaps', {'b' => id})

        compare = "#{btmp['artist']} - #{btmp['title']} [#{btmp['version']}]"
        if full_name.downcase == compare.downcase
          map_id = id
          break
        end
      end

      l = recents.length
      msg = "Iterating over #{l} recent#{l != 1 ? 's' : ''} took #{Time.now - t} seconds. "
      msg += "Map was #{map_id == -1 ? 'not ' : ''}found.\n"
      log(msg: msg)

      map_id == -1 && raise
      # "http://osusearch.com/api/search?key=&title=Freedom+Dive&artist=xi&diff_name=FOUR+DIMENSIONS&order=play_count"
    end

    beatmap = request('beatmaps', {'b' => map_id})
    beatmap.empty? && raise
    return player, beatmap
  rescue
    log(msg: "Map retrieval failed for '#{title}'.\n")
    return nil, nil
  end
end

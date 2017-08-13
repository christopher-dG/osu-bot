# coding: utf-8

require 'fileutils'
require 'httparty'
require 'json'
require 'markdown-tables'
require 'redd'
require 'yaml'

require_relative 'consts'
require_relative 'utils'
require_relative 'oppai'
require_relative 'parsing'
require_relative 'markdown'


class ScorePost

  attr_accessor :title  # String
  attr_accessor :player  # Hash: https://github.com/ppy/osu-api/wiki#user
  attr_accessor :map  # Hash: https://github.com/ppy/osu-api/wiki#beatmap
  attr_accessor :mods  # Array
  attr_accessor :bad_title  # String: Key indicating why the title sucks (todo).
  attr_accessor :error  # Bool

  def initialize(title:, manual: false, player: {}, map: {}, mods: [])
    @bad_title = ''

    if manual
      @title = title
      @mods = mods
      @player = player
      @map = map
      @error = false
      return
    end

    player_name, song_name, diff_name = split_title(title)
    @title = title
    @mods = mods_from_string(@title)
    begin
      @player = request('user', u: player_name, t: 'string')
    rescue
      puts("Fetching player data for '#{player_name}' failed.")
      @error = true
      return
    end

    begin
      @map = beatmap_search("#{song_name} [#{diff_name}]", @player)
    rescue
      @error = true
      return
    end

    # If the map is not standard, get the user's stats for the other game mode.
    if @map['mode'] != '0'
      puts("Getting player for mode: #{@map['mode']}")
      begin
        @player = request('user', u: @player['user_id'], m: @map['mode'])
      rescue
        puts("Fetching player data for '#{player_name}' failed.")
      end
    end

  end

  def inspect
    text = "ScorePost\n  "
    text += "title: #{@title}\n  player: #{@player['username']}\n  "
    text += "map: #{map_string(@map)}\n  mods: #{@mods}\n  "
    text += "bad_title: #{@bad_title}\n  error: #{@error}"
    return text
  end

end

# Get a beatmap matching a given name from a player's recent plays.
# map_name should look like 'Artist - Song [Diff]'.
# player: https://github.com/ppy/osu-api/wiki#response-1
# Returns a beatmap: https://github.com/ppy/osu-api/wiki#response
def beatmap_search(map_name, player)
  puts("Searching for '#{map_name}' with player '#{player['username']}'")
  map_id = -1
  puts("Searching player's recent events")

  player['events'].each do |e|
    if bleach(e['display_html']).include?(bleach(map_name.gsub('&', '&amp;')))
      map_id = e['beatmap_id']
      break
    end
  end

  if map_id != -1
    puts("Found beatmap match '#{map_id}' in events")
    begin
      return request('beatmaps', b: map_id)
    rescue
      puts("Fetching beatmap for '#{map_name}' from '#{map_id}' failed, continuing")
    end
  end

  puts("Map was not found in events, searching player's recent plays")
  # Use player's recent plays as a backup. This can take a while longer
  # if the player has recently played a lof of unique maps.
  seen_ids = []  # Avoid making duplicate API calls.
  time = Time.now

  begin
    recents = request('user_recent', u: player['user_id'], t: 'id')
  rescue
    puts('Fetching player\'s recent plays failed')
  else
    l = recents.length
    recents.each do |play|
      id = play['beatmap_id']
      if seen_ids.include?(id)
        puts("Skipping duplicate: '#{id}'")
        next
      end
      seen_ids.push(id)

      begin
        map = request('beatmaps', b: id)
      rescue
        puts("Fetching beatmap for '#{map_name}' failed, continuing")
        next
      end

      if bleach_cmp(map_string(map), map_name)
        puts("Found beatmap match '#{map['beatmap_id']}' in recents")
        msg = "Iterating over #{l} recent play#{plur(l)} took "
        msg += "#{round(Time.now - time, 5)} seconds, map was not retrieved"
        puts(msg)
        return map
      end
    end
  end

  msg = "Iterating over #{l} recent play#{plur(l)} "
  msg += "took #{round(Time.now - time,  5)} seconds, map was not retrieved"
  puts(msg)
  raise


  # We could use osusearch as a backup, getting the most played match:
  # https://osusearch.com/api/search?key=KEY&other=stuff&order=play_count
end

# Run the bot.
def run(limit: 25)
  puts("#{`date`}\n")
  start_time = Time.now
  # results: [[title, $comment/'fail']]
  results, attempts = [], 0
  begin
    osu = get_sub
  rescue
    puts("Reddit initialization failed.")
    exit
  end

  osu.new(limit: limit).each do |p|
    puts("\nPost title: #{p.title}")

    if should_comment(p)
      attempts += 1
      results.push([p.title, nil])
      post = ScorePost.new(title: p.title)
      if post.error
        puts('Generating a ScorePost failed')
        next
      end

      puts(post.inspect)
      begin
        comment = markdown(post)
      rescue
        puts("Not commenting on '#{post.title}'")
        next
      end

      puts("Commenting on '#{post.title}'")
      if !DRY
        p.reply(comment).distinguish(:sticky)
        p.upvote
      end
      puts("Commented:\n#{comment}\n---")
      results[-1][1] = comment
    end
  end

  comments = results.count {|t, c| !c.nil?}

  if attempts > 0
    puts("\n")
    puts("===========================================")
    puts("===========================================")
    puts("================= SUMMARY =================")
    puts("===========================================")
    puts("===========================================")

    puts("\nMade #{comments}/#{attempts} attempted comments\n")
    results.each do |title, comment|
      comment.nil? ? puts("#{title}: failed") : puts("#{title}: \n#{comment}\n")
    end
  else
    puts("\nAttempted 0 comments")
  end

  puts("Complete run took #{round(Time.now - start_time, 3)} seconds")
  puts("Made #{$request_count} API request#{plur($request_count)}\n\n")

  return nil
end


if __FILE__ == $0
  if ARGV.any? {|a| !RUN_MODES.include?(a)}
    raise("Invalid command line arguments: valid run modes are  #{RUN_MODES}")
  end

  $request_count = 0
  run
end

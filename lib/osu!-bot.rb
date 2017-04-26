# coding: utf-8

require 'date'
require 'fileutils'
require 'httparty'
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
      log("Fetching player data for '#{player_name}' failed.")
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
      log("Getting player for mode: #{@map['mode']}")
      begin
        @player = request('user', u: @player['user_id'], m: @map['mode'])
      rescue
        log("Fetching player data for '#{player_name}' failed.")
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
  log("Searching for '#{map_name}' with player '#{player['username']}'")
  map_id = -1
  log("Searching player's recent events")

  player['events'].each do |e|
    if bleach(e['display_html']).include?(bleach(map_name.gsub('&', '&amp;')))
      map_id = e['beatmap_id']
      break
    end
  end

  if map_id != -1
    log("Found beatmap match '#{map_id}' in events")
    begin
      return request('beatmaps', b: map_id)
    rescue
      log("Fetching beatmap for '#{map_name}' from '#{map_id}' failed, continuing")
    end
  end

  log("Map was not found in events, searching player's recent plays")
  # Use player's recent plays as a backup. This can take a while longer
  # if the player has recently played a lof of unique maps.
  seen_ids = []  # Avoid making duplicate API calls.
  time = Time.now

  begin
    recents = request('user_recent', u: player['user_id'], t: 'id')
  rescue
    log('Fetching player\'s recent plays failed')
  else
    l = recents.length
    recents.each do |play|
      id = play['beatmap_id']
      seen_ids.include?(id) && (log("Skipping duplicate: '#{id}'") || next)
      seen_ids.push(id)

      begin
        map = request('beatmaps', b: id)
      rescue
        log("Fetching beatmap for '#{map_name}' failed, continuing") || next
      end

      if bleach_cmp(map_string(map), map_name)
        log("Found beatmap match '#{map['beatmap_id']}' in recents")
        msg = "Iterating over #{l} recent play#{plur(l)} took "
        msg += "#{round(Time.now - time, 5)} seconds, map was not retrieved"
        log(msg)
        return map
      end
    end
  end

  msg = "Iterating over #{l} recent play#{plur(l)} "
  msg += "took #{round(Time.now - time,  5)} seconds, map was not retrieved"
  log(msg) || raise


  # We could use osusearch as a backup, getting the most played match:
  # https://osusearch.com/api/search?key=KEY&other=stuff&order=play_count
end

# Run the bot.
def run(limit: 25)
  log("#{`date`}\n", force: true)
  start_time = Time.now
  # results: [[title, $comment/'fail']]
  results, attempts = [], 0
  begin
    osu = get_sub
  rescue
    log("Reddit initialization failed.", force: true) || exit
  end

  osu.new(limit: limit).each do |p|
    log("\nPost title: #{p.title}")

    if should_comment(p)
      attempts += 1
      results.push([p.title, nil])
      post = ScorePost.new(title: p.title)

      post.error && (log('Generating a ScorePost failed') || next)

      log(post.inspect)
      begin
        comment = markdown(post)
      rescue
        log("Not commenting on '#{post.title}'") || next
      end

      log("Commenting on '#{post.title}'")
      if !DRY
        p.reply(comment).distinguish(:sticky)
        p.upvote
      end
      log("Commented:\n#{comment}\n---")
      results[-1][1] = comment
    end
  end

  comments = results.count {|t, c| !c.nil?}

  if attempts > 0
    log("\n")
    log("===========================================")
    log("===========================================")
    log("================= SUMMARY =================")
    log("===========================================")
    log("===========================================")

    log("\nMade #{comments}/#{attempts} attempted comments\n")
    results.each do |title, comment|
      comment.nil? ? log("#{title}: failed") : log("#{title}: \n#{comment}\n")
    end
  else
    log("\nAttempted 0 comments")
  end

  log("Complete run took #{round(Time.now - start_time, 3)} seconds")
  log("Made #{$request_count} API request#{plur($request_count)}\n\n")

  if !DEBUG  # Simplified summary when not debugging.
    if attempts > 0
      log("Made #{comments}/#{attempts} attempted comments\n\n", force: true)
      results.each do |title, comment|
        log("#{title}: #{comment.nil? ? 'failed' : 'succeeded'}\n", force: true)
      end
      log("\n\n", force: true)
    else
      log("Attempted 0 comments\n\n", force: true)
    end
  end
  return nil
end


if __FILE__ == $0
  if ARGV.any? {|a| !RUN_MODES.include?(a)}
    raise("Invalid command line arguments: valid run modes are  #{RUN_MODES}")
  end

  $request_count = 0
  run

  # Append the single-run results to the rolling log.
  File.open("#{File.dirname(LOG)}/rolling.log", 'a') do |rolling|
    File.open(LOG) {|f| rolling.write("#{f.read}")}
  end
end

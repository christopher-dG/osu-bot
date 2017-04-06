require 'date'
require 'fileutils'
require 'httparty'
require 'redd'

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
      if @player.nil?
        log("Emptty API response for '#{player_name}'")
        @error = true
        return
      end
    rescue
      log("Fetching player data for '#{player_name}' failed.")
      @error = true
      return
    end
    @map = beatmap_search("#{song_name} [#{diff_name}]", @player)
    @error = @map.nil?
  end

  def inspect
    text = "ScorePost\n  "
    text += "title: #{@title}}\n  player: #{@player['username']}\n  "
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
  log('Searching player\'s recent events')
  player['events'].each do |e|
    if bleach(e['display_html']).include?(bleach(map_name.gsub('&', '&amp;')))
      map_id = e['beatmap_id']
      break
    end
  end
  if map_id != -1
    begin
      log("Found beatmap match '#{map_id}' in events")
      return request('beatmaps', b: map_id)
    rescue
      log("Fetching beatmap data for '#{map_name}' from '#{map_id}' failed, continuing")
    end
  end

  log('Searching player\'s recent plays')
  # Use player's recent plays as a backup. This takes significantly longer.
  seen_ids = []  # Avoid making duplicate API calls.
  time = Time.now
  begin
    recents = request('user_recent', u: player['user_id'], t: 'id')
    l = recents.length
  rescue
    log('Fetching player\'s recent plays failed')
  else
    recents.each do |play|
      id = play['beatmap_id']
      seen_ids.include?(id) && !log("Skipping duplicate: '#{id}'") && next
      seen_ids.push(id)
      begin
        map = request('beatmaps', b: id)
      rescue
        !log("Fetching beatmap data for '#{map_name}' failed, continuing")  && next
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
  log(msg)

  map_id == -1 && log('Map was not found.')

  return nil

  # We could use osusearch as a backup, getting the most played match:
  # https://osusearch.com/api/search?key=KEY&other=stuff&order=play_count
end

# Run the bot.
def run
  File.open(LOG, 'a') {|f| f.write("#{`date`}\n")}
  start_time = Time.now
  comments, titles, c = [], [], 0
  begin
    osu = get_sub
  rescue
    !log("Reddit initialization failed.") && exit
  end

  osu.new.each do |p|
    log("\nPost title: #{p.title}")

    if should_comment(p)
      c += 1
      titles.push([p.title, 'fail'])
      post = ScorePost.new(title: p.title)

      if !post.error
        log(post.inspect)
        comment = markdown(post)

        if !comment.empty?
          titles[-1][1] = 'success'
          log("Commenting on '#{post.title}'")

          if !DRY
            p.reply(comment).distinguish(:sticky)
            p.upvote
          end

          log("Commented:\n#{comment}\n---")
          comments.push([post.title, comment])

        else
          log("Markdown generation failed for post: '#{post.title}'")
        end
      end
    end
  end

  if c > 0
    log("\n")
    log("===========================================")
    log("===========================================")
    log("================= SUMMARY =================")
    log("===========================================")
    log("===========================================")

    log("\nMade #{comments.length}/#{c} attempted comments\n")
    !comments.empty? && comments.each {|cmt| log("\n#{cmt[0]}\n#{cmt[1]}")}
  else
    log("\nAttempted 0 comments")
  end
  log("Complete run took #{round(Time.now - start_time, 3)} seconds")
  log("Made #{$request_count} API request#{plur($request_count)}\n\n")

  if !DEBUG  # Simplified summary when not debugging.
    if c > 0
      text = "Made #{comments.length}/#{c} attempted comments\n\n"
      titles.each {|t, success| text += "#{t}: #{success}\n"}
      File.open(LOG, 'a') {|f| f.write("#{text}\n\n")}
    else
      File.open(LOG, 'a') {|f| f.write("Attempted 0 comments\n\n")}
    end
  end
  return nil
end

if __FILE__ == $0
  if !ARGV.empty? && !ARGV.all? {|a| RUN_MODES.include?(a)}
    raise("Invalid command line arguments: valid run modes are  #{RUN_MODES}")
  end

  $request_count = 0
  run

  # Append the single-run results to the rolling log.
  File.open("#{File.dirname(LOG)}/rolling.log", 'a') do |rolling|
    File.open(LOG) {|f| rolling.write("#{f.read}")}
  end
end

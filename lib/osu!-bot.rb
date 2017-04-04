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
  DEBUG && log("Searching for '#{map_name}' with player '#{player['username']}'")
  map_id = -1
  DEBUG && log('Searching player\'s recent events')
  player['events'].each do |e|
    if bleach(e['display_html']).include?(bleach(map_name))
      map_id = e['beatmap_id']
      break
    end
  end
  if map_id != -1
    begin
      DEBUG && log("Found beatmap match '#{map_id}' in events")
      return request('beatmaps', b: map_id)
    rescue
      log("Fetching beatmap data for '#{map_name}' from '#{map_id}' failed, continuing")
    end
  end

  DEBUG && log('Searching player\'s recent plays')
  # Use player's recent plays as a backup. This takes significantly longer.
  seen_ids = []  # Avoid making duplicate API calls.
  DEBUG && time = Time.now
  begin
    recents = request('user_recent', u: player['user_id'], t: 'id')
    l = recents.length
  rescue
    log('Fetching player\'s recent plays failed')
  else
    recents.each do |play|
      id = play['beatmap_id']
      seen_ids.include?(id) && ((DEBUG && log("Skipping duplicate: '#{id}'")) || true) && next
      seen_ids.push(id)
      begin
        map = request('beatmaps', b: id)
      rescue
        log("Fetching beatmap data for '#{map_name}' failed, continuing")  && next
      end
      if bleach_cmp("#{map['artist']} - #{map['title']} [#{map['version']}]", map_name)
        DEBUG && log("Found beatmap match '#{map['beatmap_id']}' in recents")
        DEBUG && msg = "Iterating over #{l} recent play#{plur(l)} took "
        DEBUG && msg += "#{round(Time.now - time, 5)} seconds, map was not retrieved"
        DEBUG && log(msg)
        return map
      end
    end
  end

  DEBUG && msg = "Iterating over #{l} recent play#{plur(l)} "
  DEBUG && msg += "took #{round(Time.now - time,  5)} seconds, map was not retrieved"
  DEBUG && log(msg)

  map_id == -1 && log('Map was not found.')

  return nil

  # We could use osusearch as a backup, getting the most played match:
  # https://osusearch.com/api/search?key=KEY&other=stuff&order=play_count
end

# Run the bot.
def run
  comments, c = [], 0
  begin
    osu = get_sub
  rescue
    log("Reddit initialization failed.") && exit
  end
  osu.new.each do |p|
    DEBUG && log("\nPost title: #{p.title}")
    if should_comment(p)
      post = ScorePost.new(title: p.title)
      if !post.error
        DEBUG && log(post.inspect)
        c += 1
        comment = markdown(post)
        if !comment.empty?
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
    log("\n.=============================.")  # RIP symmetry.
    log(".=============================.")
    log(".========== SUMMARY ==========.")
    log(".=============================.")
    log(".=============================.")

    log("\nMade #{c}/#{comments.length} attempted comment#{plur(comments.length)}")
    !comments.empty? && comments.each {|cmt| log("\n#{cmt[0]}\n#{cmt[1]}")}
  else
    log('\nAttempted 0 comments')
  end
  return nil
end

if __FILE__ == $0
  if !ARGV.empty? && ARGV.all? {|a| RUN_MODES.include?(a)}
    ARGV.each {|a| global_variables.push(a)}
  elsif !ARGV.empty?
    raise("Invalid command line arguments: valid run modes are  #{RUN_MODES}")
  end
  run
  File.open("#{File.dirname(LOG)}/rolling.log", 'a') do |rolling|
    File.open(LOG) do |f|
      rolling.write("#{`date`}\n\n#{f.read}\n\n")
    end
  end
end

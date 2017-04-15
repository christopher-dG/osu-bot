# coding: utf-8

require 'httparty'
require 'redcarpet'
require 'redcarpet/render_strip'
require 'redd'

require_relative 'consts'
require_relative 'utils'

# Don't include link URLs in stripped Markdown.
class StripMarkdown < Redcarpet::Render::StripDown
  def link(link, title, content) content end
end

# Get the minimum - maximum star rating for a mapset. Returns [min, max]
# or [rating] if the mapset only has one diff.
def star_rating(mapset)
  sr = [1000, 0]  # Min - max star ratings
  mapset.each do |diff|
    val = diff['difficultyrating'].to_f
    val < sr[0] && sr[0] = val
    val > sr[1] && sr[1] = val
  end

  # We'll show x.xx - x.xx no matter what for multi-diff sets
  # even if the minimum and max are the same, at least for now.
  if sr[0] == sr[1] && mapset.length == 1
    sr = [round(sr[0], 2)]
  else
    sr[0], sr[1] = round(sr[0], 2), round(sr[1], 2)
  end
  return sr
end

# Reply to a comment containing  beatmap links.
def reply(comment)
  log("Constructing reply for '#{comment.body}'")
  text = ''
  seen = []
  comment.body.split.each do |token|
    match = token.match(/osu\.ppy\.sh\/[sb]\/[0-9]+/).to_s

    if !match.empty?
      log("Matched token: #{token}")

      begin
        if match =~ /s\/[0-9]+/  # Beatmap set.
          mapset = request('beatmaps', s: match.split('/')[-1])
          map = mapset[0]
        else  # Single diff.
          map = request('beatmaps', b: match.split('/')[-1])
          mapset = request('beatmaps', s: map['beatmapset_id'])
        end
      rescue
        # Skip any mapsets that fail.
        log("A request failed for comment token: '#{token}'") || next
      end

      # Skip any maps or mapsets that we've already seen.
      if seen.include?(map['beatmapset_id']) || seen.include?(map['beatmap_id'])
        log("Skipping duplicate mapset '#{map['beatmapset_id']}'") || next
      end

      sr = star_rating(mapset)

      # Don't use map_string here because we don't want the diff name.
      map_name = "#{map['artist']} - #{map['title']}"
      link_url = "#{OSU_URL}/s/#{map['beatmapset_id']}"
      dl_url = "#{OSU_URL}/d/#{map['beatmapset_id']}"
      text += "[#{map_name}](#{link_url}) [(#{DOWNLOAD})](#{dl_url}) "
      text += "(#{sr.join(' - ')} #{STAR})\n\n"

      seen += [map['beatmap_id'], map['beatmapset_id']]
      log("Seen maps/mapsets: #{seen}")
    end
  end

  if !text.empty?
    text += "***\n\n^(I'm a bot. )[^Source](#{GH_URL})^( | )[^Developer](#{DEV_URL})\n\n"
    !DRY && comment.save && comment.reply(text)
    log("Commenting:\n#{text}")
    return true
  end
end


if __FILE__ == $0
  $request_count = 0
  sub = get_sub
  comments = sub.comments(limit: 100)
  saved = get_bot.saved
  count = 0
  markdown = Redcarpet::Markdown.new(StripMarkdown.new)
  success = []

  comments.each do |c|
    log("Comment body: #{c.body}")
    if c.author.name != 'osu-bot' &&
       markdown.render(c.body) =~ /osu\.ppy\.sh\/[sb]\/[0-9]+/
      if !saved.any? {|s| c.id == s.id}
        reply(c) && count += 1 && success.push(c.body)
      else
        log("Skipped saved comment: #{c.body}")
      end
    end
  end

  log("Posted #{count} beatmap link comment#{plur(count)}", force: true)
  (success.length > 0 && log('Comments replied to:')) || log(success.join("\n"))
  log("Made #{$request_count} API request#{plur($request_count)}")
end

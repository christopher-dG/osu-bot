# coding: utf-8

require 'redd'

require_relative 'consts'
require_relative 'utils'

def reply(comment)
  log("Constructing reply for '#{comment.body}'")
  text = ''
  seen = []
  comment.body.split.each do |token|
    match = token.match(/osu\.ppy\.sh\/[sb]\/[0-9]+/).to_s

    if !match.empty? && !seen.include?(match)
      seen.push(match)
      log("Matched token: #{token}")
      begin
        puts match
        if match =~ /s\/[0-9]+/
          map = request('beatmaps', s: match.split('/')[-1])
        else
          map = request('beatmaps', b: match.split('/')[-1])
        end
      rescue
        puts map
        log("A request failed for comment token: '#{token}'")
        next
      end

      if map.nil?
        log("Enpty API response for comment token: '#{token}'")
        next
      end

      link_url = "#{OSU_URL}/s/#{map['beatmapset_id']}"
      dl_url = "#{OSU_URL}/d/#{map['beatmapset_id']}"
      text += "[#{map_string(map)}](#{link_url}) [(⇓)](#{dl_url})\n\n"
    end
  end

  if !text.empty?
    if !DRY
      comment.save && comment.reply(text)
    end
    log("Commenting: #{text}")
    return true
  end
end

if __FILE__ == $0
  $request_count = 0
  sub = get_sub
  comments = sub.comment_stream
  saved = get_bot.saved
  count = 0

  (0..99).each do
    c = comments.next
    log("Comment body: #{c.body}")
    if c.author.name != 'osu-bot' && c.body =~ /osu\.ppy\.sh\/[sb]\/[0-9]+/
      if !saved.any? {|s| c.id == s.id}
        reply(c) && count += 1
      else
        log("Skipped saved comment: #{c.body}")
      end
    end
  end

  File.open(LOG, 'a') {|f| f.write("Posted #{count} beatmap link comment#{plur(count)}")}
  log("Made #{$request_count} API request#{plur($request_count)}")
end

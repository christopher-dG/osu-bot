require 'httparty'

KEY = '69f173c71dde7925a8cab800e5432a27e0071c15'  # API key

title = 'Cookiezi | Tsubaki - Kyun Kyun Tamaran Inaba-tan. [Lunatic] +HDDT | FC | 98.13% | 518pp | #1'

tokens = title.split('|')
player = tokens[0].strip
map = tokens[1]
song = map[0...map.index('[')].strip  # Artist - Title
diff = map[map.index('[')..map.index(']')]  # [Diff Name]
url = "https://osu.ppy.sh/api/get_user?k=#{KEY}&u=#{player}&type=string"

begin
  usr_response = HTTParty.get(url)
rescue
  puts "API call to #{url} failed."
else
  events = usr_response.parsed_response[0]['events']
end

puts "Got #{events.length} events."

map_id = -1
full_name = "#{song} #{diff}"
for event in events
  if event['display_html'].include?(full_name)
    map_id = event['beatmap_id']
  end
end

if map_id == -1
  puts "Did not find beatmap: #{full_name}"
else
  url = "https://osu.ppy.sh/api/get_beatmaps?k=#{KEY}&b=#{map_id}"
  begin
    bmp_response = HTTParty.get(url)
  rescue
    puts "API call to #{url} failed."
  else
    beatmap = bmp_response.parsed_response[0]
    bmp_url = "https://osu.ppy.sh/b/#{beatmap['beatmap_id']}"
    puts bmp_url
  end
end

# Criteria for a post to be considered a score post. Be deliberately lenient,
#   false positives are not a problem whereas false negatives are.
def is_score_post(post)
  return post.title =~ /.*\|.*-.*\[.*\].*/ && !post.is_self
end

# Split a title into relevant pieces: player, song, and diff names.
def split_title(title)
  tokens = title.split('|')
  player_name = tokens[0].match(/[\w\-\[\]][ \w\-\[\]]+[\w\-\[\]]/).to_s
  song_name = tokens[1][0...map.rindex('[')].strip  # Artist - Title
  diff_name = tokens[1][tokens[1].rindex('[') + 1...tokens[1].rindex(']')]
  return player_name, song_name, diff_name
end

# Get the enabled mods from an integer.
# https://github.com/ppy/osu-api/wiki#mods
# Returns '+Mod1Mod2Mod3' or an empty string.
def mods_from_int(mod_int)
  i = mod_int
  mods = []
  for mod in BITWISE_MODS.keys.reverse
    if i == 0 && !mod_list.empty?
      mod_list.include?('NC') && mod_list.delete('DT')
      [
        'EZ', 'HD', 'HR', 'DT', 'NC', 'HR', 'FL',
        'NF', 'SD', 'PF', 'RL', 'AP', 'AT', 'SO',
      ].each {|m| mod_list.delete(m) && mod_list.push(m)}
      return "+#{mod_list.join('')}"
    elsif mod <= i
      mod_list.push(BITWISE_MODS[mod])
      i -= mod
    end
  end
  return ''
end

# Get a modstring from a post title.
# Returns '+Mod1Mod2Mod3' or an empty string.
def mods_from_string(title)
  is_modlist = Proc.new {|list| list.all? {|m| MODS.include?(m)}}
  begin
    string = title[title.index('|')..-1].match(/\+[[A-Z],]+/).to_s[1..-1]
    list = string.include?(',') ? string.split(',') : string.scan(/[A-Z]{1,2}/)
    return is_modlist.call(list) ? "+#{list.join('')}" : ''
  rescue
    tokens = title[title.index('|' + 1)..-1].split(' ')
    for token in tokens
      list = token.gsub(',', '').scan(/[A-Z]{1,2}/)
      if is_modlist.call(list)
        return "+#{list.join('')}"
      end
    end
    return ''
  end
end

# Get difficulty values for `map` with and without `mods`.
# Returns a hash in the form: {'property' => ['nomod', 'modded']}. If there are
#   no mods or the mods do not affect the difficulty, values are length-one arrays.
def diff(map, mods)
  sr = map['difficultyrating'].to_f.round(2).to_s
  ar = map['diff_approach']
  cs = map['diff_size']
  od = map['diff_overall']
  hp = map['diff_drain']

  begin
    modded = oppai_analyze(map['beatmap_id'], mods)
  rescue
    return { 'CS' => [cs], 'AR' => [ar], 'OD' => [od], 'HP' => [hp], 'SR' => [sr]}
  end

  ez_hp_scalar = 0.5
  hr_hp_scalar = 1.4
  hp_max = 10

  m_sr = /[0-9]*\.[0-9]*\sstars/.match(oppai).to_s.split(' ')[0].to_f.round(2).to_s
  m_ar = parse_oppai.call('ar', oppai)
  m_ar = m_ar.to_i == m_ar ? m_ar.to_i : m_ar
  m_cs = parse_oppai.call('cs', oppai)
  m_cs = m_cs.to_i == m_cs ? m_cs.to_i : m_cs
  m_od = parse_oppai.call('od', oppai)
  m_od = m_od.to_i == m_od ? m_od.to_i : m_od

  # Oppai does not handle HP drain.
  if mods.include?("EZ")
    m_hp = (hp.to_f * ez_hp_scalar).round(2)
    m_hp = m_hp.to_i == m_hp ? m_hp.to_i.to_s : m_hp.to_s
  elsif mods.include?("HR")
    m_hp = (hp.to_f * hr_hp_scalar).round(2)
    m_hp = m_hp > hp_max ?
             hp_max.to_s : m_hp.to_i == m_hp ? m_hp.to_i.to_s : m_hp.to_s
  else
    m_hp = hp
  end

  return {
    'CS' => [cs, modded['cs']], 'AR' => [ar, modded['ar']],
    'OD' => [od, modded['od']], 'HP' => [hp, modded['hp']],
    'SR' => [sr, moddded['sr']],
  }
end

# Get tthe ranked status of a beatmap.
def ranked_status(map)
  # '2' => 'Approved' but that's equivalent to 'Ranked'.
  approvals = {'1' => 'Ranked', '2' => 'Ranked', '3' => 'Qualified', '4' => 'Loved'}
  if approvals.key?(map['approved'])
    return "#{approvals[map['approved']]} (#{map['approved_date'][0..9]})"
  else
    return 'Unranked'
  end
end

# Get adjusted  BPM and length values for HT/DT/NC.
# Length is the number of seconds as either an int or string.
# Returns [adjusted bpm, adjusted length_seconds]
def adjust_bpm_length(bpm, length, mods)
  bpm = bpm.to_i
  length = length.to_i
  adj_bpm, adj_length = bpm, length
  if mods =~ /DT|NC/
    adj_bpm = (bpm * 1.5).to_f.round(0)
    adj_length = (length * 0.66).to_f.round(0)
  elsif mods =~ /HT/
    adj_bpm = (bpm * 0.66).to_f.round(0)
    adj_length = (length * 1.5).to_f.round(0)
  end
  return adj_bpm.to_i, adj_length.to_i
end


# Get a score's percentage accuracy as a float.
def acc(score)
  c = {
    300 => score['count300'].to_i, 100 => score['count100'].to_i,
    50 => score['count50'].to_i, 0 => score['countmiss'].to_i
  }
  o = c.values.sum.to_f  # Total objects.
  return ([c[300] / o, c[100] / o * 1/3.to_f, c[50] / o * 1/6.to_f].sum * 100).round(2)
end

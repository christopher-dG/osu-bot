if ENV['CI'] == 'true'
  require 'simplecov'
  SimpleCov.start
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require_relative File.join('..', 'lib', 'linker-bot')
require 'test/unit'
require 'date'
require 'json'

TEST_DIR = File.expand_path(File.dirname(__FILE__))  # Absolute path to file folder.
oppai = Proc.new do |map, mods|
  `../oppai/oppai #{map} #{mods}`
end

class FakePost  # Mimic a Reddit post.
  attr_accessor :title
  attr_accessor :is_self
  def initialize(t, s)
    @title = t
    @is_self = s
  end
end

class Fake < Hash  # Mimic a beatmap dict.
  def initialize(d)
    d.each do |k, v|
      self[k] = v
    end
  end
end
FakeMap = FakePlayer = FakeScore = Fake

def template_sub!(template, map, mods)
  pp_nomod = get_pp(map['beatmap_id'], '').split(' &#124; ')
  pp_mods = get_pp(map['beatmap_id'], mods).split(' &#124; ')
  diff = get_diff_info(map, mods)
  status = get_status(map['beatmap_id'])
  length = convert_s(map['total_length'].to_i)

  template.gsub!('$BEATMAP_ID', map['beatmap_id'])
  template.gsub!('$ARTIST', map['artist'])
  template.gsub!('$TITLE', map['title'])
  template.gsub!('$DIFF', map['version'])
  template.gsub!('$CREATOR', map['creator'])
  template.gsub!('$LENGTH', length)
  template.gsub!('$BPM', map['bpm'])
  template.gsub!('$PLAYS', map['playcount'])
  template.gsub!('$CS', diff['CS'][0])
  template.gsub!('$AR', diff['AR'][0])
  template.gsub!('$OD', diff['OD'][0])
  template.gsub!('$HP', diff['HP'][0])
  template.gsub!('$SR', diff['SR'][0])
  template.gsub!('$PP95', pp_nomod[0])
  template.gsub!('$PP98', pp_nomod[1])
  template.gsub!('$PP99', pp_nomod[2])
  template.gsub!('$PP100', pp_nomod[3])
  template.gsub!('$STATUS', status)
  if diff['SR'].length == 2
    template.gsub!('$MODS', mods)
    adjust_bpm_length!(map, mods)
    m_length = convert_s(map['total_length'].to_i)
    template.gsub!('$M_LENGTH', m_length)
    template.gsub!('$M_BPM', map['bpm'])
    template.gsub!('$M_CS', diff['CS'][1])
    template.gsub!('$M_AR', diff['AR'][1])
    template.gsub!('$M_OD', diff['OD'][1])
    template.gsub!('$M_HP', diff['HP'][1])
    template.gsub!('$M_SR', diff['SR'][1])
    template.gsub!('$M_PP95', pp_mods[0])
    template.gsub!('$M_PP98', pp_mods[1])
    template.gsub!('$M_PP99', pp_mods[2])
    template.gsub!('$M_PP100', pp_mods[3])
  end
end

class TestLinkerBot < Test::Unit::TestCase

  def test_search
    # Todo
    user = File.open("#{TEST_DIR}/user.json") {|f| JSON.parse(f.read)}
    recents = File.open("#{TEST_DIR}/recents.json") {|f| JSON.parse(f.read)}
  end

  def test_split_title
    assert_equal(
      split_title('Player | Artist - Song [Diff] Other'),
      ['Player', 'Artist - Song', '[Diff]'],
    )
    assert_equal(
      split_title('Player Name | Artist Name - Song Name [Diff Name]'),
      ['Player Name', 'Artist Name - Song Name', '[Diff Name]'],
    )
    assert_equal(
      split_title('Player|Artist-Song[Diff]Other'),
      ['Player', 'Artist - Song', '[Diff]'],
    )
    assert_equal(
      split_title('p (x) | a - s [d] x'),
      ['p', 'a - s', '[d]'],
    )
    assert_equal(
      split_title('p(x) | a - s [d] x'),
      ['p', 'a - s', '[d]'],
    )
    assert_equal(
      split_title('p | a [x] - s [d] x'),
      ['p', 'a [x] - s', '[d]'],
    )
    assert_equal(
      split_title('p | a - s [x] [d] x'),
      ['p', 'a - s [x]', '[d]'],
    )
    assert_equal(
      split_title('p | a - s [x][d] x'),
      ['p', 'a - s [x]', '[d]'],
    )
    assert_equal(
      split_title('[p] | a - s [d] x'),
      ['[p]', 'a - s', '[d]'],
    )
    assert_equal(
      split_title('p [x] | a - s [d] x'),
      ['p [x]', 'a - s', '[d]'],
    )


  end

  def test_get_diff_info
    map = FakeMap.new(
      {
        'beatmap_id' => '297663',
        'difficultyrating' => '4.539580345153809',
        'diff_approach' => '9',
        'diff_size' => '4',
        'diff_drain' => '8',
        'diff_overall' => '8',
        'total_length' => '180',
        'bpm' => '174',
        'version' => 'Another',
        'playcount' => '-1',  # Impossible to hardcode.
        'creator' => 'galvenize',
        'title' => 'Nightmare (Maxin Remix)',
        'artist' => 'SirensCeol',
      }
    )
    player = FakePlayer.new(
      {
        'user_id' => '84841',
        'username' => 'CXu',
        'pp_rank' => '21',
        'playcount' => '105093',
        'pp_raw' => '10683.9',
        'accuracy' => '99.05836486816406',
      }
    )
    top_score = FakeScore.new(
      {
        'artist' => '',
        'title' => '',
        'version' => '',
        'pp' => '',
      }
    )

    assert_equal(
      get_diff_info(map, ''),
      {'SR' => ['4.54'], 'CS' => ['4'], 'AR' => ['9'], 'OD' => ['8'], 'HP' => ['8']}
    )
    # assert_equal(
    #   get_diff_info(map, '+FL'),
    #   {'SR' => ['4.54'], 'CS' => ['4'], 'AR' => ['9'], 'OD' => ['8'], 'HP' => ['8']}
    # )

    assert_equal(
      get_diff_info(map, '+DT'),
      {
        'SR' => ['4.54', '6.26'], 'AR' => ['9', '10.33'], 'CS' => ['4', '4'],
        'OD' => ['8', '9.75'], 'HP' => ['8', '8']
      }
    )
    assert_equal(
      get_diff_info(map, '+DTFL'),
      {
        'SR' => ['4.54', '6.26'], 'AR' => ['9', '10.33'], 'CS' => ['4', '4'],
        'OD' => ['8', '9.75'], 'HP' => ['8', '8']
      }
    )
    assert_equal(
      get_diff_info(map, '+HR'),
      {
        'SR' => ['4.54', '4.83'], 'AR' => ['9', '10'], 'CS' => ['4', '5.2'],
        'OD' => ['8', '10'], 'HP' => ['8', '10']
      }
    )
  end

  def test_get_mods
    assert_equal(get_mods('p | a - s [d] +HDDT x'), '+HDDT')
    assert_equal(get_mods('p | a - s [d] HDDT x'), '+HDDT')
    assert_equal(get_mods('p | a - s [d] x x'), '')
    assert_equal(get_mods('p | a - s [d] +HDHH'), '')
    assert_equal(get_mods('p | a - s [d] HDHH'), '')
    assert_equal(get_mods('p | a - s [d] x x x x +HDHR'), '+HDHR')
    assert_equal(get_mods('p | a - s [d] x HDHR x x HDDT'), '+HDHR')
    assert_equal(get_mods('p | a - s [d] x HDHR x x +HDDT'), '+HDDT')
  end

  def test_get_status
    # Todo
  end

  def test_get_pp
    # Todo
  end

  def test_adjust_bpm_length
    # Todo
  end

  def test_get_sub
    begin
      osu = get_sub
    rescue  # In case of Reddit maintenance.
      return
    else
      assert_equal(osu.class, Redd::Models::Subreddit)
      assert_equal(osu.display_name, 'osugame')
      assert(osu.respond_to?('new'))
    end
  end

  # def test_gen_comment
  #   post = FakePost.new('Player | Song - Artist [Diff]', false)
  #   map = FakeMap.new(
  #     {
  #       'beatmap_id' => '297663',
  #       'difficultyrating' => '4.539580345153809',
  #       'diff_approach' => '9',
  #       'diff_size' => '4',
  #       'diff_drain' => '8',
  #       'diff_overall' => '8',
  #       'total_length' => '180',
  #       'bpm' => '174',
  #       'version' => 'Another',
  #       'playcount' => '-1',  # Impossible to hardcode.
  #       'creator' => 'galvenize',
  #       'title' => 'Nightmare (Maxin Remix)',
  #       'artist' => 'SirensCeol',
  #     }
  #   )

  #   # The map is mutated by adjust_bpm_length! so we need to undo it.
  #   revert_bpm_length = Proc.new do |map|
  #     map['total_length'] = '180'
  #     map['bpm'] = '174'
  #   end

  #   t = File.open("#{TEST_DIR}/nomod.txt") {|f| f.read}
  #   mods = ""
  #   template_sub!(t, map, mods)
  #   assert_equal(gen_comment(post.title, map).chomp, t.chomp)


  #   post = FakePost.new('Player | Song - Artist [Diff] +FLNF', false)
  #   t = File.open("#{TEST_DIR}/mod.txt") {|f| f.read}
  #   mods = "+FLNF"
  #   template_sub!(t, map, mods)
  #   assert_equal(gen_comment(post.title, map).chomp, t.chomp)

  #   post = FakePost.new('Player | Song - Artist [Diff] +HDDT', false)
  #   t = File.open("#{TEST_DIR}/mod.txt") {|f| f.read}
  #   mods = "+HDDT"
  #   template_sub!(t, map, mods)
  #   revert_bpm_length.call(map)
  #   assert_equal(gen_comment(post.title, map).chomp, t.chomp)
  #   revert_bpm_length.call(map)

  #   post = FakePost.new('Player | Song - Artist [Diff] +HT', false)
  #   t = File.open("#{TEST_DIR}/mod.txt") {|f| f.read}
  #   mods = "+HT"
  #   template_sub!(t, map, mods)
  #   revert_bpm_length.call(map)
  #   assert_equal(gen_comment(post.title, map).chomp, t.chomp)

  # end

  def test_convert_s
    assert_equal(convert_s(1), '0:01')
    assert_equal(convert_s(48), '0:48')
    assert_equal(convert_s(60), '1:00')
    assert_equal(convert_s(61), '1:01')
    assert_equal(convert_s(80), '1:20')
    assert_equal(convert_s(1000), '16:40')
  end

  def test_is_score_post
    assert(is_score_post(FakePost.new('ppp | a - s [d]o', false)))
    assert(is_score_post(FakePost.new('ppp | a - s [d]', false)))
    assert(is_score_post(FakePost.new('--- | a - s [d]', false)))
    assert(is_score_post(FakePost.new('[[[ | a - s [d]', false)))
    assert(is_score_post(FakePost.new(']]] | a - s [d]', false)))
    assert(is_score_post(FakePost.new('___ | a - s [d]', false)))
    assert(is_score_post(FakePost.new('ppp | a - s [d]', false)))
    assert(is_score_post(FakePost.new('ppp|a-s[d]', false)))
    assert(is_score_post(FakePost.new('ppp (x) | a - s [d]', false)))
    assert(is_score_post(FakePost.new('ppp [x] | a - s [d]', false)))
    assert(is_score_post(FakePost.new('ppp | s (x) - a [d]', false)))
    assert(is_score_post(FakePost.new('ppp | s [x] - a [d]', false)))
    assert(is_score_post(FakePost.new('ppp | a - s (x) [d]', false)))
    assert(is_score_post(FakePost.new('ppp | a - s [x] [d]', false)))
    assert(!is_score_post(FakePost.new('ppp | a - s [d]', true)))
    assert(!is_score_post(FakePost.new('', false)))
    assert(!is_score_post(FakePost.new('x', false)))
    assert(!is_score_post(FakePost.new('ppp | a - s [d', false)))
    assert(!is_score_post(FakePost.new('ppp | a - s []', false)))
    assert(!is_score_post(FakePost.new('ppp | a - s d]', false)))
    assert(!is_score_post(FakePost.new('ppp | s - [d]', false)))
    assert(!is_score_post(FakePost.new('ppp | s a [d]', false)))
    assert(!is_score_post(FakePost.new('ppp | - a [d]', false)))
    assert(!is_score_post(FakePost.new('ppp a - s [d]', false)))
    assert(!is_score_post(FakePost.new(' | a - s [d]', false)))
  end

  def test_now
    if DateTime.now.second == 59
      sleep(2)
    end
    t1 = now
    t2 = DateTime.now.to_s
    assert_equal(t1, "#{t2[5..9]}-#{t2[0..3]}_#{t2[11..15]}")
    sleep(10)
    t1 = now
    t2 = DateTime.now.to_s
    assert_equal(t1, "#{t2[5..9]}-#{t2[0..3]}_#{t2[11..15]}")
  end

end

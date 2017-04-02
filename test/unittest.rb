if ENV['CI'] == 'true'
  require 'simplecov'
  SimpleCov.start
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require_relative File.join('..', 'lib', 'osu-bot')
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

class TestOsuBot < Test::Unit::TestCase

  def test_search
    # Todo: dump user and beatmap data at some instance and test on that.
  end

  def test_get_bitwise_mods
    assert_equal(get_bitwise_mods(0), '')
    assert_equal(get_bitwise_mods(1), '+NF ')
    assert_equal(get_bitwise_mods(2), '+EZ ')
    assert_equal(get_bitwise_mods(3), '+EZNF ')
    assert_equal(get_bitwise_mods(8), '+HD ')
    assert_equal(get_bitwise_mods(9), '+HDNF ')
    assert_equal(get_bitwise_mods(16), '+HR ')
    assert_equal(get_bitwise_mods(24), '+HDHR ')
    assert_equal(get_bitwise_mods(72), '+HDDT ')
    assert_equal(get_bitwise_mods(576), '+NC ')
    assert_equal(get_bitwise_mods(584), '+HDNC ')
    assert_equal(get_bitwise_mods(1048), '+HDHRFL ')
    assert_equal(get_bitwise_mods(16384), '+PF ')
    assert_equal(get_bitwise_mods(16385), '+NFPF ')
  end

  def test_split_title
    assert_equal(
      split_title('Player | Artist - Song [Diff] Other'),
      ['Player', 'Artist - Song', 'Diff'],
    )
    assert_equal(
      split_title('Player Name | Artist Name - Song Name [Diff Name]'),
      ['Player Name', 'Artist Name - Song Name', 'Diff Name'],
    )
    assert_equal(
      split_title('Player|Artist-Song[Diff]Other'),
      ['Player', 'Artist - Song', 'Diff'],
    )
    assert_equal(split_title('p (x) | a - s [d] x'), ['p', 'a - s', 'd'])
    assert_equal(split_title('p(x) | a - s [d] x'), ['p', 'a - s', 'd'])
    assert_equal(split_title('p | a [x] - s [d] x'), ['p', 'a [x] - s', 'd'])
    assert_equal(split_title('p | a - s [x] [d] x'), ['p', 'a - s [x]', 'd'])
    assert_equal(split_title('p | a - s [x][d] x'), ['p', 'a - s [x]', 'd'])
    assert_equal(split_title('[p] | a - s [d] x'), ['[p]', 'a - s', 'd'])
    assert_equal(split_title('p [x] | a - s [d] x'), ['p [x]', 'a - s', 'd'])
  end

  def test_get_diff_info
    map = {
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
    player = {
      'user_id' => '84841',
      'username' => 'CXu',
      'pp_rank' => '21',
      'playcount' => '105093',
      'pp_raw' => '10683.9',
      'accuracy' => '99.05836486816406',
    }
    top_score = {
      'artist' => '',
      'title' => '',
      'version' => '',
      'pp' => '',
    }

    assert_equal(
      get_diff_info(map, ''),
      {'SR' => ['4.54'], 'CS' => ['4'], 'AR' => ['9'], 'OD' => ['8'], 'HP' => ['8']}
    )
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
      sub = get_sub(true)
    rescue  # In case of Reddit maintenance.
      return
    else
      assert_equal(sub.class, Redd::Models::Subreddit)
      assert_equal(sub.display_name, 'osubottesting')
      assert(sub.respond_to?('new'))
    end
  end

  def template_sub(template, map, player, mods)
    text = template
    pp_nomod = get_pp(map['beatmap_id'], '').split(' &#124; ')
    pp_mods = get_pp(map['beatmap_id'], mods).split(' &#124; ')
    diff = get_diff_info(map, mods)
    status = get_status(map)
    length = convert_s(map['total_length'].to_i)
    top_play = request('user_best', {'u' => player['user_id']})
    top_map = request('beatmaps', {'b' => top_play['beatmap_id']})
    top_combo = "(#{top_play['maxcombo']}/#{top_map['max_combo']})"

    text.gsub!('$BEATMAP_ID', map['beatmap_id'])
    text.gsub!('$ARTIST', map['artist'])
    text.gsub!('$TITLE', map['title'])
    text.gsub!('$DIFF', map['version'])
    text.gsub!('$CREATOR', map['creator'])
    text.gsub!('$MAX_COMBO', map['max_combo'])
    text.gsub!('$LENGTH', length)
    text.gsub!('$BPM', map['bpm'])
    text.gsub!('$PLAYCOUNT', "#{map['playcount']} plays")
    text.gsub!('$CS', diff['CS'][0])
    text.gsub!('$AR', diff['AR'][0])
    text.gsub!('$OD', diff['OD'][0])
    text.gsub!('$HP', diff['HP'][0])
    text.gsub!('$SR', diff['SR'][0])
    text.gsub!('$PP95', pp_nomod[0])
    text.gsub!('$PP98', pp_nomod[1])
    text.gsub!('$PP99', pp_nomod[2])
    text.gsub!('$PP100', pp_nomod[3])
    text.gsub!('$STATUS', status)
    text.gsub!('$PLAYER_NAME', player['username'])
    text.gsub!('$PLAYER_ID', player['user_id'])
    text.gsub!('$PLAYER_RANK', player['pp_rank'])
    text.gsub!('$PLAYER_PP', player['pp_raw'])
    text.gsub!('$PLAYER_ACC', player['accuracy'].to_f.round(2).to_s)
    text.gsub!('$PLAYER_PLAYCOUNT', player['playcount'])
    text.gsub!('$TOP_ID', top_map['beatmap_id'])
    text.gsub!('$TOP_TITLE', top_map['title'])
    text.gsub!('$TOP_ARTIST', top_map['artist'])
    text.gsub!('$TOP_DIFF', top_map['version'])
    text.gsub!('$TOP_MODS', get_bitwise_mods(top_play['enabled_mods'].to_i))
    text.gsub!('$TOP_PP', top_play['pp'].to_f.round(0).to_s)
    text.gsub!('$TOP_ACC', get_acc(top_play).to_s)
    text.gsub!('$TOP_FC', map['perfect'] == '1' ? 'FC ' : '')
    text.gsub!('$TOP_COMBO', map['perfect'] == '1' ? '' : top_combo)

    if diff['SR'].length == 2
      text.gsub!('$MODS', mods)
      m_bpm, m_length = adjust_bpm_length(map['bpm'].to_i, map['total_length'].to_i, mods)
      m_length = convert_s(m_length)
      text.gsub!('$M_LENGTH', m_length)
      text.gsub!('$M_BPM', m_bpm.to_s)
      text.gsub!('$M_CS', diff['CS'][1])
      text.gsub!('$M_AR', diff['AR'][1])
      text.gsub!('$M_OD', diff['OD'][1])
      text.gsub!('$M_HP', diff['HP'][1])
      text.gsub!('$M_SR', diff['SR'][1])
      text.gsub!('$M_PP95', pp_mods[0])
      text.gsub!('$M_PP98', pp_mods[1])
      text.gsub!('$M_PP99', pp_mods[2])
      text.gsub!('$M_PP100', pp_mods[3])
    end
    return text
  end

  def test_gen_comment
    # Todo: other game modes.
    nomod = File.open("#{TEST_DIR}/res/nomod_template") {|f| f.read.chomp}
    mod = File.open("#{TEST_DIR}/res/mod_template") {|f| f.read.chomp}
    player = {
      'user_id' => '123',
      'username' => 'Test Player',
      'playcount' => '123',
      'pp_raw' => '123',
      'pp_rank' => '123',
      'accuracy' => '12.3456789',
    }
    map = {
      'beatmap_id' => '123',
      'title' => 'Test Map',
      'artist' => 'Test Artist',
      'version' => 'Test Diff',
      'max_combo' => '123',
      'bpm' => '123',
      'total_length' => '123',
      'creator' => 'Test Creator',
      'playcount' => '123',
      'approved' => '1',
      'approved_date' => '2013-07-02 01:01:12"',
      'difficultyrating' => '4.58394',
      'diff_approach' => '8',
      'diff_size' => '4',
      'diff_drain' => '6',
      'diff_overall' => '9',
    }
    assert_equal(gen_comment(map, player, ''), template_sub(nomod, map, player, ''))
    assert_equal(gen_comment(map, player, '+HDHR'), template_sub(mod, map, player, '+HDHR'))
  end

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

  def test_request
    puts("Test player: Doomsday")
    puts("Test beatmap: xi - FREEDOM DiVE [FOUR DIMENSIONS]")
    user_id = '18983'
    username = 'Doomsday'
    artist = 'xi'
    title = 'FREEDOM DiVE'
    diff = 'FOUR DIMENSIONS'
    result = request('user_recent', {'u' => user_id})
    if result.empty?
      puts('WARNING: results from `request` are empty.')
    else
      play = result[0]
      assert(play.keys.include?('beatmap_id'))
      assert_equal(play['user_id'], user_id)
    end
  end

end

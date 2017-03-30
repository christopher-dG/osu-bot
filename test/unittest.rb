if ENV['CI'] == 'true'
  require 'simplecov'
  SimpleCov.start
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require_relative File.join('..', 'lib', 'linker-bot')
require 'test/unit'
require 'date'

TEST_DIR = File.expand_path(File.dirname(__FILE__))  # Absolute path to file folder.
oppai = Proc.new do |map, mods|
  `../oppai/oppai #{map} #{mods}`
end

class FakePost  # Mimic a Reddit post.
  attr_reader :title
  attr_accessor :is_self
  def initialize(t, s)
    @title = t
    @is_self = s
  end
end

class FakeMap < Hash  # Mimic a beatmap dict.
  def initialize(d)
    d.each do |k, v|
      self[k] = v
    end
  end
end

def template_sub!(template, map)
  template.gsub!('$BEATMAP_ID', map['beatmap_id'])
  template.gsub!('$ARTIST', map['artist'])
  template.gsub!('$TITLE', map['title'])
  template.gsub!('$DIFF', map['version'])
  template.gsub!('$CREATOR', map['creator'])
  template.gsub!('$LENGTH', convert_s(map['total_length'].to_i))
  template.gsub!('$BPM', map['bpm'])
  template.gsub!('$PLAYS', map['playcount'])
  template.gsub!('$CS', map['diff_size'])
  template.gsub!('$AR', map['diff_approach'])
  template.gsub!('$OD', map['diff_overall'])
  template.gsub!('$HP', map['diff_drain'])
  template.gsub!('$SR', map['difficultyrating'].to_f.round(2).to_s)
end

class TestLinkerBot < Test::Unit::TestCase

  def test_search
    # I'm not sure that I can test this, since it needs for a map
    # to be in the given user's recent plays.
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
    assert_equal(
      get_diff_info(map, ''),
      {'SR' => ['4.54'], 'CS' => ['4'], 'AR' => ['9'], 'OD' => ['8'], 'HP' => ['8']}
    )
    assert_equal(
      get_diff_info(map, '+FL'),
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

  def test_gen_comment
    post = FakePost.new('Player | Song - Artist [Diff]', false)
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
    t = File.open("#{TEST_DIR}/nomod.txt") {|f| f.read}
    template_sub!(t, map)
    assert_equal(gen_comment(post.title, map).chomp, t.chomp)
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
    assert(is_score_post(FakePost.new('p | a - s [d]o', false)))
    assert(is_score_post(FakePost.new('p | a - s [d]', false)))
    assert(is_score_post(FakePost.new('p | a - s [d]', false)))
    assert(is_score_post(FakePost.new('p|a-s[d]', false)))
    assert(is_score_post(FakePost.new('p (x) | a - s [d]', false)))
    assert(is_score_post(FakePost.new('p [x] | a - s [d]', false)))
    assert(is_score_post(FakePost.new('p | s (x) - a [d]', false)))
    assert(is_score_post(FakePost.new('p | s [x] - a [d]', false)))
    assert(is_score_post(FakePost.new('p | a - s (x) [d]', false)))
    assert(is_score_post(FakePost.new('p | a - s [x] [d]', false)))
    assert(!is_score_post(FakePost.new('p | a - s [d]', true)))
    assert(!is_score_post(FakePost.new('', false)))
    assert(!is_score_post(FakePost.new('x', false)))
    assert(!is_score_post(FakePost.new('p | a - s [d', false)))
    assert(!is_score_post(FakePost.new('p | a - s []', false)))
    assert(!is_score_post(FakePost.new('p | a - s d]', false)))
    assert(!is_score_post(FakePost.new('p | s - [d]', false)))
    assert(!is_score_post(FakePost.new('p | s a [d]', false)))
    assert(!is_score_post(FakePost.new('p | - a [d]', false)))
    assert(!is_score_post(FakePost.new('p a - s [d]', false)))
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

if ENV['CI'] == 'true'
  require 'simplecov'
  SimpleCov.start
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require_relative File.join('..', 'lib', 'linker-bot')
require 'test/unit'
require 'date'

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
  template.gsub!('$ARTIST', map['artist'])
  template.gsub!('$TITLE', map['title'])
  template.gsub!('$CREATOR', map['creator'])
  template.gsub!('$LENGTH', map['total_length'])
  template.gsub!('$BPM', map['bpm'])
  template.gsub!('$PLAYS', map['playcount'])
  template.gsub!('$CS', map['diff_size'])
  template.gsub!('$AR', map['diff_approach'])
  template.gsub!('$OD', map['diff_overall'])
  template.gsub!('$HP', map['diff_drain'])
  template.gsub!('$SR', map['difficultyrating'].to_f.round(2))
end

class TestLinkerBot < Test::Unit::TestCase

  def test_search
  end

  def test_split_title
    assert_equal(
      split_title('Player | Artist - Song [Diff] Other'),
      ['Player', 'Artist - Song', '[Diff]']
    )
    assert_equal(
      split_title('Player | Artist - Song [Diff] Other'),
      ['Player', 'Artist - Song', '[Diff]']
    )

  end

  def test_get_diff_info
  end

  def test_get_mods
    assert_equal(get_mods('Player | Artist - Song Name [Diff] +HDDT Other'), '+HDDT')
    assert_equal(get_mods('Player | Artist - Song [Diff] HDDT Other'), '+HDDT')
  end

  def test_get_sub
    osu = get_sub
    assert_equal(osu.class, Redd::Models::Subreddit)
    assert_equal(osu.display_name, 'osugame')
    assert(osu.respond_to?('new'))
  end

  def test_gen_comment
    post = FakePost.new('Player | Song - Artist [Diff]', false)
    c = gen_comment(post.title, 's')
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
    assert(is_score_post(FakePost.new('p | s - a [d]o', false)))
    assert(is_score_post(FakePost.new('p | s - a [d]', false)))
    assert(is_score_post(FakePost.new('p | s - a [d]', false)))
    assert(is_score_post(FakePost.new('p|s-a[d]', false)))
    assert(is_score_post(FakePost.new('p (x) | s - a [d]', false)))
    assert(is_score_post(FakePost.new('p [x] | s - a [d]', false)))
    assert(is_score_post(FakePost.new('p | s (x) - a [d]', false)))
    assert(is_score_post(FakePost.new('p | s [x] - a [d]', false)))
    assert(is_score_post(FakePost.new('p | s - a (x) [d]', false)))
    assert(is_score_post(FakePost.new('p | s - a [x] [d]', false)))
    assert(!is_score_post(FakePost.new('p | s - a [d]', true)))
    assert(!is_score_post(FakePost.new('', false)))
    assert(!is_score_post(FakePost.new('x', false)))
    assert(!is_score_post(FakePost.new('p | s - a [d', false)))
    assert(!is_score_post(FakePost.new('p | s - a []', false)))
    assert(!is_score_post(FakePost.new('p | s - a d]', false)))
    assert(!is_score_post(FakePost.new('p | s - [d]', false)))
    assert(!is_score_post(FakePost.new('p | s a [d]', false)))
    assert(!is_score_post(FakePost.new('p | - a [d]', false)))
    assert(!is_score_post(FakePost.new('p s - a [d]', false)))
    assert(!is_score_post(FakePost.new(' | s - a [d]', false)))
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

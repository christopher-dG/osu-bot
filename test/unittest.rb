# coding: utf-8

if ENV['CI'] == 'true'
  require 'simplecov'
  SimpleCov.start
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require_relative File.join('..', 'lib', 'osu!-bot')
require 'test/unit'

# Absolute path to file folder.
TEST_DIR = File.expand_path(File.dirname(__FILE__))

# Mock a Reddit post.
class Post
  attr_accessor :title
  attr_accessor :is_self
  attr_accessor :comments
  def initialize(title, is_self, comments)
    @title = title;
    @is_self = is_self
    @comments = comments
  end
end

# Mock a Reddit comment.
class Comment
  attr_accessor :author
  def initialize(name) @author = User.new(name) end
end

# Mock a Reddit user.
class User
  attr_accessor :name
  def initialize(name) @name = name end
end

class TestOsuBot < Test::Unit::TestCase

  def test_should_comment
    comment = Comment.new('osu-bot')
    post = Post.new('ppp | t - a [d] +m', false, [comment])
    assert(!should_comment(post))
    post.comments[0].author.name = 'test'
    assert(should_comment(post))
    post.is_self = true
    assert(!should_comment(post))
    post.is_self = false
    assert(should_comment(post))
    post.title = 'ppp|t-a[d'
    assert(!should_comment(post))
    post.title = 'ppp|t-a[]'
    assert(!should_comment(post))
    post.title = 'ppp|t-ad]'
    assert(!should_comment(post))
    post.title = 'ppp|ta[d]'
    assert(!should_comment(post))
    post.title = 'pta[d]'
    assert(!should_comment(post))
    post.title = '|t-a[d]'
    assert(!should_comment(post))
  end

  def test_split_title
    title = 'ppp | t - a [d] +m'
    assert_equal(split_title(title), ['ppp', 't - a', 'd'])
    # Todo: make 't-a' work.
    # title = 'p(d)|t-a[d]+m'
    # assert_equal(split_title(title), ['p', 't - a', 'd'])
    title = 'ppp| t - a [d][d2]'
    assert_equal(split_title(title), ['ppp', 't - a [d]', 'd2'])
  end

  def test_mods_from_int
    assert(mods_from_int(0).empty?)
    assert_equal(mods_from_int(1), %w(NF))
    assert_equal(mods_from_int(2), %w(EZ))
    assert_equal(mods_from_int(3), %w(EZ NF))
    assert_equal(mods_from_int(8), %w(HD))
    assert_equal(mods_from_int(9), %w(HD NF))
    assert_equal(mods_from_int(16), %w(HR))
    assert_equal(mods_from_int(24), %w(HD HR))
    assert_equal(mods_from_int(72), %w(HD DT))
    assert_equal(mods_from_int(88), %w(HD DT HR))
    assert_equal(mods_from_int(576), %w(NC))
    assert_equal(mods_from_int(584), %w(HD NC))
    assert_equal(mods_from_int(1048), %w(HD HR FL))
    assert_equal(mods_from_int(16384), %w(PF))
    assert_equal(mods_from_int(16385), %w(NF PF))
  end

  def test_mods_from_string
    assert(mods_from_string('p | a - s [d] xx').empty?)
    assert_equal(mods_from_string('ppp | a - s [d] +HDDT x'), %w(HD DT))
    assert_equal(mods_from_string('ppp | a - s [d] HDDT x'), %w(HD DT))
    assert_equal(mods_from_string('ppp | a - s [d] +DTHD x'), %w(HD DT))
    assert_equal(mods_from_string('ppp | a - s [d] DTHD x'), %w(HD DT))
    assert(mods_from_string('ppp | a - s [d] +HDHH').empty?)
    assert(mods_from_string('ppp | a - s [d] HDHH').empty?)
    assert_equal(mods_from_string('ppp | a - s [d] x x x x +HDHR'), %w(HD HR))
    assert_equal(mods_from_string('ppp | a - s [d] x HDHR x x HDDT'), %w(HD HR))
    assert_equal(mods_from_string('ppp | a - s [d] x HDHR x x +HDDT'), %w(HD DT))
    assert_equal(mods_from_string('ppp | a - s [d] +HD,DT x'), %w(HD DT))
    assert_equal(mods_from_string('ppp | a - s [d] HD,DT x'), %w(HD DT))
  end

  def test_diff_vals
  end

  def test_ranked_status
    map = {'approved' => '1', 'approved_date' => '2017-07-02 01:01:01'}
    assert_equal(ranked_status(map), 'Ranked (2017-07-02)')
    map['approved'] = '2'
    assert_equal(ranked_status(map), 'Ranked (2017-07-02)')
    map['approved'] = '3'
    assert_equal(ranked_status(map), 'Qualified (2017-07-02)')
    map['approved'] = '4'
    assert_equal(ranked_status(map), 'Loved (2017-07-02)')
    map['approved'] = '0'
    assert_equal(ranked_status(map), 'Unranked')
    map['approved'] = '-1'
    assert_equal(ranked_status(map), 'Unranked')
    map['approved'] = '-2'
    assert_equal(ranked_status(map), 'Unranked')
  end

  def test_adjusted_timing
    bpm, length = '24', '24'
    assert_equal(adjusted_timing(bpm, length, []), ['24', '24'])
    assert_equal(adjusted_timing(bpm, length, ['DT']), ['36', '16'])
    assert_equal(adjusted_timing(bpm, length, ['NC']), ['36', '16'])
    assert_equal(adjusted_timing(bpm, length, ['HT']), ['18', '32'])
  end

  def test_accuracy
    score = {
      'count300' => '1', 'count100' => '0', 'count50' => 0, 'countmiss' => '0'
    }
    assert_equal(accuracy(score), '100')
    score['count300'], score['countmiss'] = '1', '1'
    assert_equal(accuracy(score), '50')
    score['count300'], score['countmiss'] = '0', '1'
    assert_equal(accuracy(score), '0')
    score['count100'], score['countmiss'] = '1', '0'
    assert_equal(accuracy(score), '33.33')
    score['count50'], score['count100'] = '1', '0'
    assert_equal(accuracy(score), '16.67')
    score = {
      'count300' => '45', 'count100' => '30', 'count50' => '10', 'countmiss' => 15
    }
    assert_equal(accuracy(score), '56.67')
  end

  def test_bleach
    assert_equal(bleach('test'), 'test')
    assert_equal(bleach('TEST'), 'test')
    assert_equal(bleach('TEST test'), 'testtest')
    assert_equal(bleach("test\t\ntest\n"), 'testtest')
    assert_not_equal(bleach("test-test"), 'testtest')
    assert_not_equal(bleach("test_test"), 'testtest')
    assert_not_equal(bleach("test[test"), 'testtest')
  end

  def test_bleach_cmp
    assert(bleach_cmp('test', 'test'))
    assert(bleach_cmp('TEST', 'test'))
    assert(bleach_cmp('TEST test', 'testtest'))
    assert(bleach_cmp("test\t\ntest\n", 'testtest'))
    assert(!bleach_cmp("test-test", 'testtest'))
    assert(!bleach_cmp("test_test", 'testtest'))
    assert(!bleach_cmp("test[test", 'testtest'))
  end

  def test_format_num
    assert_equal(format_num(1000), '1,000')
    assert_equal(format_num('1000'), '1,000')
    assert_equal(format_num('1234567'), '1,234,567')
  end

  def test_plur
    assert(plur('1').empty?)
    assert_equal(plur('0'), 's')
    assert_equal(plur('2'), 's')
    assert_equal(plur('1.01'), 's')
  end

  def test_map_string
    map = {'artist' => 'Artist', 'title' => 'Title', 'version' => 'Diff'}
    assert_equal(map_string(map), 'Artist - Title [Diff]')
    map = {'artist' => 'artist', 'title' => 'title', 'version' => 'diff'}
    assert_equal(map_string(map), 'artist - title [diff]')
  end

  def test_timestamp
    assert_equal(timestamp('0'), '0:00')
    assert_equal(timestamp('120'), '2:00')
    assert_equal(timestamp('130'), '2:10')
    assert_raises(RuntimeError) {timestamp('-1')}
  end

  def test_request
    # Todo: unit tests for other game modes.
    player_name = 'Doomsday'
    player_id = '18983'
    map_id = '129891'

    response = request('user', u: player_name, t: 'string')
    assert(response.keys.include?('user_id'))
    assert(response.keys.include?('events'))
    response = request('user', u: player_id, t: 'id')
    assert(response.keys.include?('user_id'))
    assert(response.keys.include?('events'))

    begin
      response = request('user_recent', u: player_name, t: 'string')
    rescue
      puts('WARNING: empty response for recent plays')
    else
      assert_equal(response.class, Array)
      assert(response[0].keys.include?('enabled_mods'))
      assert(response[0].keys.include?('perfect'))
    end
    begin
      response = request('user_recent', u: player_id, t: 'string')
    rescue
      puts('WARNING: empty response for recent plays')
    else
      assert_equal(response.class, Array)
      assert(response[0].keys.include?('enabled_mods'))
      assert(response[0].keys.include?('perfect'))
    end

    response = request('beatmaps', b: map_id)
    assert_equal(response.class, Hash)
    assert(response.keys.include?('artist'))
    assert(response.keys.include?('bpm'))
    response = request('beatmaps', s: '39804')
    assert_equal(response.class, Array)
    assert(response[0].keys.include?('artist'))
    assert(response[0].keys.include?('bpm'))

    response = request('user_best', u: player_name, t: 'string')
    assert_equal(response.class, Hash)
    assert(response.keys.include?('beatmap_id'))
    assert(response.keys.include?('perfect'))
    response = request('user_best', u: player_id, t: 'id')
    assert_equal(response.class, Hash)
    assert(response.keys.include?('beatmap_id'))
    assert(response.keys.include?('perfect'))

    response = request('scores', u: player_name, b: map_id, t: 'string')
    assert_equal(response.class, Hash)
    assert(response.keys.include?('score'))
    assert(response.keys.include?('username'))
    response = request('scores', u: player_id, b: map_id, t: 'id')
    assert_equal(response.class, Hash)
    assert(response.keys.include?('score'))
    assert(response.keys.include?('username'))
  end


end

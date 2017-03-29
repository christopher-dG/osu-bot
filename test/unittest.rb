if ENV['CI'] == 'true'
  require 'simplecov'
  SimpleCov.start
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require_relative File.join('..', 'lib', 'linker-bot')
require 'test/unit'
require 'date'

NOMOD_TEMPLATE = "Beatmap: [$ARTIST - $TITLE [$DIFF]](https://osu.ppy.sh/b/$BEATMAP_ID)\n\nCreator: [$CREATOR](https://osu.ppy.sh/u/$CREATOR)\n\nLength: $LENGTH - BPM: $BPM - Plays: $PLAYS\n\nSR: $SR - AR: $AR- CS: $CS - OD: $OD - HP: $HP\n\n***\n\n^(I'm a bot. )[^Source](https://github.com/christopher-dG/osu-map-linker-bot)^( | )[^Developer](https://reddit.com/u/PM_ME_DOG_PICS_PLS)"
MOD_TEMPLATE = "Beatmap: [$ARTIST - $TITLE [$DIFF]](https://osu.ppy.sh/b/$BEATMAP_ID)\n\nCreator: [$CREATOR](https://osu.ppy.sh/u/$CREATOR)\n\nLength: $LENGTH - BPM: $BPM - Plays: $PLAYS\n\nSR: $SR - AR: $AR- CS: $CS - OD: $OD - HP: $HP\n\n$MODS\n\nSR: $M_SR - AR: $M_AR- CS: $M_CS - OD: $M_OD - HP: $M_HP\n\n***\n\n^(I'm a bot. )[^Source](https://github.com/christopher-dG/osu-map-linker-bot)^( | )[^Developer](https://reddit.com/u/PM_ME_DOG_PICS_PLS)"

class FakePost  # Mimic a Reddit post.
  attr_accessor :title
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

class TestLinkerBot < Test::Unit::TestCase

  def test_search
  end

  def test_get_diff_info
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
    post = FakePost.new('Player | Song - Artist [Diff]', false)
    assert(is_score_post(post))
  end

  def test_now
    # Technically this could fail, given sufficiently bad luck.
    t1 = now
    t2 = DateTime.now.to_s
    assert_equal(t1, "#{t2[5..9]}-#{t2[0..3]}_#{t2[11..15]}")
    sleep(3)
    t1 = now
    t2 = DateTime.now.to_s
    assert_equal(t1, "#{t2[5..9]}-#{t2[0..3]}_#{t2[11..15]}")
  end

end

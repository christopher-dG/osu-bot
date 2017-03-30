# osu!-map-linker-bot

[![Build Status](https://travis-ci.org/christopher-dG/osu-map-linker-bot.svg?branch=master)](https://travis-ci.org/christopher-dG/osu-map-linker-bot)
[![codecov](https://codecov.io/gh/christopher-dG/osu-map-linker-bot/branch/master/graph/badge.svg)](https://codecov.io/gh/christopher-dG/osu-map-linker-bot)

[/u/map-linker-bot](https://reddit.com/u/map-linker-bot) is a Reddit bot to comment on [/r/osugame](https://reddit.com/r/osugame) score posts with beatmap information.

## To score posters

The bot depends on you to properly format your title! The beginning of your post title should look something like this:
```
Player Name | Song Artist - Song Title [Diff Name] +Mods
```

For example:

```
Cookiezi | xi - FREEDOM DiVE [FOUR DIMENSIONS] +HDHR 99.83% FC 800pp *NEW PP RECORD*
```

### Detailed guidelines:

* The text before the first `|` must begin with the player name. Extra text can be added in `(parentheses)` like so:
  ```Player Name (#1 global) | ...```
* Mods must be all capitalized and separated by either nothing or commas.
  * The following styles will work: `+HDHR`, `HDHR`, `+HD,HR`, `HD,HR`
  * The following syles will not work: `HD HR`, `HD-HR`, `+HD-HR`, `+HD +HR`
* Typos in the player, artist, song, or diff names will cause the bot to fail.
* The rightmost set of `[square brackets]` between the first and second `|` separators must contain the diff name.
  * The following will work: ```Player | Artist - Song [Diff] +DT | FC [7.9*]```
  * The following will not work: ```Player | Artist - Song [Diff] FC 99.2% [first fc]```
* Make sure to pad the `-` separating the artist and song name with spaces.
If you don't do this and the song or artist contains a `-`, the bot won't work.

In general, you can't go wrong with [/r/osugame](https://reddit.com/r/osugme)'s well-established posting format
___

Credit for mod calculations goes to [Francesco149](https://github.com/Francesco149/oppai) and [ThePooN](https://github.com/ThePooN/osu-ModPropertiesCalculator).

If you have comments or suggestions for the bot, feel free to [open an issue](https://github.com/christopher-dG/osu-map-linker-bot/issues/new) or [message me on Reddit](https://reddit.com/u/PM_ME_DOG_PICS_PLS).

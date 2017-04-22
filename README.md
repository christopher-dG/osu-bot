# osu!-bot

[/u/osu-bot](https://reddit.com/u/osu-bot) is a Reddit bot to post beatmap and player information to /r/osugame score posts.

## To Score Posters

The bot depends on you to properly format your title! The beginning of your post title should look something like this:
```
Player Name | Song Artist - Song Title [Diff Name] +Mods
```

For example:

```
Cookiezi | xi - FREEDOM DiVE [FOUR DIMENSIONS] +HDHR 99.83% FC 800pp *NEW PP RECORD*
```

### Detailed Guidelines

* The text before the first `|` must begin with the player name. Extra text can be added in `(parentheses)` like so:
  ```Player Name (#1 global) | ...```
* Mods are case-insensitive, but they must be separated by either nothing or commas.
  * The following styles will work: `+HDHR`, `HDHR`, `+HD,HR`, `HD,HR`
  * The following syles will not work: `HD HR`, `HD-HR`, `+HD-HR`, `+HD +HR`
* Typos in the player, artist, song, or diff names will cause the bot to fail.
* The rightmost set of `[square brackets]` between the first and second `|` separators must contain the diff name.
  * The following will work: ```Player | Artist - Song [Diff] +DT | FC [7.9*]```
  * The following will not work: ```Player | Artist - Song [Diff] FC 99.2% [first fc]```

In general, you can't go wrong with [/r/osugame](https://reddit.com/r/osugame)'s well-established posting format.

### Reporting Errors

If you see a mistake anywhere in a comment, post a reply beginning with `!error` to open an issue (no GitHub account required).

For example: ```!error AR9 + DT is 10.3, not 10```

#### What's in it for me?

The bot will upvote your post as soon as it comments. Isn't that enough?

***

Credit for mod/pp calculations goes to [Francesco149](https://github.com/Francesco149/oppai).

If you have comments or suggestions for the bot, feel free to [open an issue](https://github.com/christopher-dG/osu-bot/issues/new) or [message me on Reddit](https://www.reddit.com/message/compose/?to=PM_ME_DOG_PICS_PLS).

And if you want to thank me in some way, I'll happily accept [the gift of supporter](https://new.ppy.sh/u/3172543).

***

****Disclaimer: this project is in no way affiliated with [osu!](https://osu.ppy.sh).****

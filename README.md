# OsuBot

[/u/osu-bot](https://reddit.com/u/osu-bot) is a Reddit bot that posts beatmap
and player information to [/r/osugame](https://reddit.com/r/osugame) score posts.

### Formatting Score Posts

The bot depends on you to properly format your title! The beginning of your
post title should look something like this:

```
Player Name | Song Artist - Song Title [Diff Name] +Mods
```

For example:

```
Cookiezi | xi - FREEDOM DiVE [FOUR DIMENSIONS] +HDHR 99.83% FC 800pp *NEW PP RECORD*
```

There are plenty of other subtleties to title formatting that will/won't work,
but almost all common styles will work just fine.

### Summoning The Bot

In addition to commenting on score posts, the bot can reply to your comments
when you ask it to. To do so, begin your comment by tagging the bot, followed
by one command per line. Note that the order of the commands determines the
order in the reply.

| Command | Arguments | Description | Usage |
| :-: | :-: | :-: | :-: |
| `!player` | `username` | Creates a player information table for the given player. For now, this will always retrieve stats for osu!std. | `!player Vaxei` |
| `!map` | `beatmap_id [+mods] [acc%]` | Creates a map information table for a single diff, optionally with given mods and accuracy. Note that the argument must be a *beatmap* id, and not a *beatmapset* id. | `!map 1233051 +HD 98.5%` |
| `!leaderboard` | `beatmap_id [n] [+mods]` | Displays a map's leaderboard. By default, the top 5 scores of any mod combination are showed. | `!leaderboard 1316353 10 +HR`

A comment using multiple commands might look like this:

```
/u/osu-bot !player Toy
!map 888715 97%
!map 1179007 +HDHR
```

Due to Markdown formatting, this will all end up on one line, but it won't
cause any problems (and it'll look better).

If you'd like to see a new command, please [get in touch](#contact)!

### Development Dependencies

* [Docker](https://www.docker.com/)
* [`oppai`](https://github.com/Francesco149/oppai-ng) binary somewhere on your
  `$PATH`

### Contact

If you have ideas, feedback, or anything else to say, feel free to
[open an issue](https://github.com/christopher-dG/OsuBot.jl/issues/new), or
send me a message:

* Reddit: `/u/PM_ME_DOG_PICS_PLS`
* Discord: `Chris | Slow Twitch#7120`
* osu!: `Slow Twitch`

***

Credit for mod/pp calculations goes to
[Francesco149](https://github.com/Francesco149/oppai-ng).

If you want to thank me in some way, I'll happily accept
[the gift of supporter](https://osu.ppy.sh/users/3172543).

**This project is not affiliated with [osu!](https://osu.ppy.sh) in any way.**

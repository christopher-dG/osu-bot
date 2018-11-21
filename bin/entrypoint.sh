#!/usr/bin/env bash

if [[ $1 = 'bash' ]]; then
    exec bash
elif [[ $1 = 'julia' ]]; then
    exec julia
elif [[ $1 = 'test' ]]; then
    exec julia --color=yes -e 'Pkg.test("OsuBot")'
else
    exec $APP/bin/bot.jl "$@"
fi

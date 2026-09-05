#!/bin/sh
set -u

MAX_PCT=98
STEP_PCT=10

cur=$(brightnessctl get 2>/dev/null || true)
max=$(brightnessctl max 2>/dev/null || true)

if [ -n "$cur" ] && [ -n "$max" ] && [ "$max" -gt 0 ] 2>/dev/null; then
    cur_pct=$((cur * 100 / max))

    if [ "$cur_pct" -ge "$MAX_PCT" ]; then
        brightnessctl set "${MAX_PCT}%"
        exit 0
    fi

    target=$((cur_pct + STEP_PCT))
    [ "$target" -gt "$MAX_PCT" ] && target=$MAX_PCT
    brightnessctl set "${target}%"
else
    ddcutil setvcp 10 + 10 || true
fi

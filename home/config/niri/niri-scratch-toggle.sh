#!/bin/bash

set -uo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/nyxniri-scratch.lock"
flock -n 9 || exit 0

SCRATCH_APP_ID="scratchpad"
TMUX_SESSION="scratch"

read -r win_id is_focused < <(niri msg -j windows 2>/dev/null \
    | jq -r --arg id "$SCRATCH_APP_ID" \
        '.[] | select((.app_id == $id) or (.title | test("scratchpad"; "i"))) | "\(.id) \(.is_focused)"' \
    | head -n1)

spawn_scratch() {
    if command -v tmux >/dev/null 2>&1; then
        niri msg action spawn -- \
            ghostty --window-title=Scratchpad -e tmux new-session -A -D -s "$TMUX_SESSION" \
            "fish -C 'function fish_title; echo Scratchpad; end' -C 'function fish_greeting; end' -C 'set -g fish_history scratchpad'" \; set-option status off
    else
        niri msg action spawn -- \
            ghostty --window-title=Scratchpad
    fi
}

if [ -z "${win_id:-}" ]; then
    spawn_scratch
elif [ "${is_focused:-false}" = "true" ]; then
    niri msg action close-window --id "$win_id"
else
    niri msg action close-window --id "$win_id"
    sleep 0.1
    spawn_scratch
fi

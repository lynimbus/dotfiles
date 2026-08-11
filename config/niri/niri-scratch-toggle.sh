#!/bin/bash
# NyxNiri Scratchpad Terminal Toggle (Minimalist & Tmux-backed)
# Mod+~ -> toggle a floating scratchpad terminal
#
# Architecture:
#   tmux session "scratch" lives in the background.
#   ghostty window (title "Scratchpad") is just a display frontend.
#   - Show: spawn ghostty -> tmux attach (scrollback/processes preserved)
#   - Hide: close ghostty window -> tmux detaches (session stays alive)
#
# 本机适配 (2026-08-13): kitty -> ghostty (无 --app-id, 改用 window-title 匹配);
# fish_title 锁定为 "Scratchpad" 防止标题被 prompt 改写。

# shellcheck disable=SC2317
set -uo pipefail

# ── Serialization Lock (Non-blocking: fast fail on rapid double keypresses) ──
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/nyxniri-scratch.lock"
flock -n 9 || exit 0

# ── Configuration ───────────────────────────────────────────────────
SCRATCH_APP_ID="scratchpad"
TMUX_SESSION="scratch"

# ── 1-Pass Window Lookup & Parser (Zero redundant subshells) ────────
read -r win_id is_focused < <(niri msg -j windows 2>/dev/null \
    | jq -r --arg id "$SCRATCH_APP_ID" \
        '.[] | select((.app_id == $id) or (.title | test("scratchpad"; "i"))) | "\(.id) \(.is_focused)"' \
    | head -n1)

# ── Spawn Helper with Graceful Fallback ──────────────────────────────
spawn_scratch() {
    if command -v tmux >/dev/null 2>&1; then
        niri msg action spawn -- \
            ghostty --window-title=Scratchpad -e tmux new-session -A -D -s "$TMUX_SESSION" \
            "fish -C 'function fish_title; echo Scratchpad; end' -C 'function fish_greeting; end' -C 'set -g fish_history scratchpad'" \; set-option status off
    else
        # Fallback if tmux is missing
        niri msg action spawn -- \
            ghostty --window-title=Scratchpad
    fi
}

# ── Main Control Logic ──────────────────────────────────────────────
if [ -z "${win_id:-}" ]; then
    # No scratchpad window -> spawn and attach
    spawn_scratch
elif [ "${is_focused:-false}" = "true" ]; then
    # Window currently focused -> hide (close frontend ghostty window)
    niri msg action close-window --id "$win_id"
else
    # Window exists on another workspace/unfocused -> move focus to current workspace
    niri msg action close-window --id "$win_id"
    sleep 0.1
    spawn_scratch
fi

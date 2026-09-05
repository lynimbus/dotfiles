#!/bin/bash
set -uo pipefail

exec 9> "${XDG_RUNTIME_DIR:-/tmp}/nyxniri-eyecare.lock"
flock -w 5 9 || exit 1

NIRI_DIR="$HOME/.config/niri"
EFFECTS_LINK="$NIRI_DIR/effects.kdl"
NORMAL_EFFECTS="$NIRI_DIR/effects_normal.kdl"
EYECARE_EFFECTS="$NIRI_DIR/effects_eyecare.kdl"

EYECARE_TEMP=5500

LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/nyxniri-eyecare.log"

HAS_NOCTALIA=false
if command -v noctalia >/dev/null 2>&1; then
    HAS_NOCTALIA=true
fi

CURRENTLY_ON=false
if [ "$(readlink "$EFFECTS_LINK" 2>/dev/null)" = "$EYECARE_EFFECTS" ]; then
    CURRENTLY_ON=true
fi

apply_effects() {
    local target
    if [ "$1" = "on" ]; then
        target="$EYECARE_EFFECTS"
    else
        target="$NORMAL_EFFECTS"
    fi

    ln -sfn "$target" "$EFFECTS_LINK"
    if [ "$(readlink "$EFFECTS_LINK" 2>/dev/null)" != "$target" ]; then
        echo "$(date '+%F %T') [eyecare] symlink swap failed (target=$target)" >> "$LOG_FILE"
    fi

    if command -v niri >/dev/null 2>&1; then
        if ! niri msg action load-config-file >>"$LOG_FILE" 2>&1; then
            sleep 0.2
            niri msg action load-config-file >>"$LOG_FILE" 2>&1 || true
        fi
    fi
}

if [ "${1:-}" = "--sync" ]; then
    link_target="$(readlink "$EFFECTS_LINK" 2>/dev/null || true)"
    if [ "$link_target" != "$EYECARE_EFFECTS" ] && [ "$link_target" != "$NORMAL_EFFECTS" ]; then
        ln -sfn "$NORMAL_EFFECTS" "$EFFECTS_LINK"
        CURRENTLY_ON=false
        echo "$(date '+%F %T') [eyecare] healed broken effects.kdl -> Normal" >> "$LOG_FILE"
        if command -v niri >/dev/null 2>&1; then
            niri msg action load-config-file >>"$LOG_FILE" 2>&1 || true
        fi
    fi
    sleep 1
    if [ "$HAS_NOCTALIA" = "true" ]; then
        noctalia msg nightlight-disable 2>/dev/null || true
    fi
    pkill -x wlsunset 2>/dev/null || true
    if [ "$CURRENTLY_ON" = "true" ]; then
        if command -v wlsunset >/dev/null 2>&1; then
            nohup wlsunset -T 6500 -t "$EYECARE_TEMP" -d 0.3 -S 00:00 -s 00:00 >/dev/null 2>&1 9>&- &
        fi
    fi
    exit 0
fi

if [ "$HAS_NOCTALIA" = "true" ]; then
    noctalia msg nightlight-disable 2>/dev/null || true
fi
pkill -x wlsunset 2>/dev/null || true

IS_TURNING_ON=false

if [ "$CURRENTLY_ON" = "true" ]; then
    apply_effects off
else
    apply_effects on
    IS_TURNING_ON=true
fi

if [ "$IS_TURNING_ON" = "true" ]; then
    sleep 0.05
    nohup wlsunset -T 6500 -t "$EYECARE_TEMP" -d 0.3 -S 00:00 -s 00:00 >/dev/null 2>&1 9>&- &
fi

if [ "$IS_TURNING_ON" = "true" ]; then
    notify-send -t 2000 "Eye Care : On"
else
    notify-send -t 2000 "Eye Care : OFF"
fi

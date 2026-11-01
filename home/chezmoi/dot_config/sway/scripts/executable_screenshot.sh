#!/usr/bin/env bash
# Region screenshot — grim | satty workflow ported from the niri setup in
# this repo (home/desktop/screenshot.sh). Falls back to a plain file when
# satty is not installed. Requires grim + slurp (both in the image).
set -euo pipefail

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

GEOMETRY="$(slurp)"
# slurp returns nothing when the user presses Escape
if [[ -z "$GEOMETRY" ]]; then
    exit 0
fi

STAMP="$(date +%Y%m%d-%H%M%S)"

if command -v satty >/dev/null 2>&1; then
    grim -g "$GEOMETRY" -t ppm - | satty \
        --filename - \
        --output-filename "$DIR/satty-$STAMP.png" \
        --early-exit \
        --copy-command wl-copy
else
    grim -g "$GEOMETRY" -o "$DIR/screenshot-$STAMP.png"
    wl-copy <"$DIR/screenshot-$STAMP.png" || true
    command -v notify-send >/dev/null 2>&1 && notify-send "Screenshot" "$DIR/screenshot-$STAMP.png" || true
fi

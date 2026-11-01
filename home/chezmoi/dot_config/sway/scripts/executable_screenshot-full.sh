#!/usr/bin/env bash
# Full-screen screenshot to ~/Pictures/Screenshots.
set -euo pipefail

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +%Y%m%d-%H%M%S).png"

grim "$FILE"
wl-copy <"$FILE" || true
command -v notify-send >/dev/null 2>&1 && notify-send "Screenshot" "$FILE" || true

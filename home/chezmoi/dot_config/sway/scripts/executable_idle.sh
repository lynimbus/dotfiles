#!/usr/bin/env bash
# Lock/sleep policy for the sway session (started from ~/.config/sway/config).
set -euo pipefail

swayidle -w \
    timeout 300 'swaylock -f -c 1e1e2e' \
    timeout 600 'swaymsg "output * dpms off"' \
    resume 'swaymsg "output * dpms on"' \
    before-sleep 'swaylock -f -c 1e1e2e'

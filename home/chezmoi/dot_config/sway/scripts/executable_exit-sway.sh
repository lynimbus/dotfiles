#!/usr/bin/env bash
# Confirm-before-exit for the sway session.
set -euo pipefail
swaynag -t warning \
    -m 'Exit sway? This ends your Wayland session.' \
    -b 'Yes, exit sway' 'swaymsg exit' \
    -b 'No, go back' 'swaymsg mode default'

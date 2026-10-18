#!/usr/bin/env bash

set -euo pipefail

exec grim -t ppm -g "$(slurp -o -d -F monospace)" - |
  satty \
    --filename - \
    --copy-command=wl-copy \
    --annotation-size-factor 2.0 \
    --output-filename="$(xdg-user-dir PICTURES)/Screenshots/Screenshot from %Y-%m-%d %H:%M:%S.png" \
    --actions-on-enter="save-to-clipboard,exit" \
    --brush-smooth-history-size=5 \
    --disable-notifications

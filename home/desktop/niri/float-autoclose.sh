#!/usr/bin/env bash

set -uo pipefail

float_app_id="com.mitchellh.ghostty.float"

declare -A tracked

close_float() {
  niri msg action close-window --id "$1" >/dev/null 2>&1
}

track_open_floats() {
  local id
  while IFS= read -r id; do
    tracked["$id"]=1
  done < <(niri msg --json windows | jq -r --arg app "$float_app_id" '.[] | select(.app_id == $app) | .id')
}

handle_event() {
  local event=$1
  local id focused open_id

  case "$event" in
    *'"WindowOpenedOrChanged"'*)
      id=$(jq -r --arg app "$float_app_id" '.WindowOpenedOrChanged.window | select(.app_id == $app) | .id // empty' <<<"$event")
      [[ -z $id ]] && return
      tracked["$id"]=1
      if [[ $(jq -r '.WindowOpenedOrChanged.window.is_focused' <<<"$event") == true ]]; then
        for open_id in "${!tracked[@]}"; do
          [[ $open_id == "$id" ]] && continue
          close_float "$open_id"
          unset 'tracked[$open_id]'
        done
      fi
      ;;
    *'"WindowClosed"'*)
      id=$(jq -r '.WindowClosed.id' <<<"$event")
      unset 'tracked[$id]'
      ;;
    *'"WindowFocusChanged"'*)
      focused=$(jq -r '.WindowFocusChanged.id // empty' <<<"$event")
      for open_id in "${!tracked[@]}"; do
        [[ $open_id == "$focused" ]] && continue
        close_float "$open_id"
        unset 'tracked[$open_id]'
      done
      ;;
  esac
}

while true; do
  track_open_floats
  while IFS= read -r event; do
    handle_event "$event"
  done < <(niri msg --json event-stream)
  sleep 1
done

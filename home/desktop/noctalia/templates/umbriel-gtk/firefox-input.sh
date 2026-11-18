#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
template="$config_home/noctalia/templates/umbriel-gtk/firefox-buttons.css"
umbriel_config="$config_home/umbriel/config.toml"
input_file="${XDG_CACHE_HOME:-$HOME/.cache}/noctalia/umbriel-gtk/firefox-buttons-input.css"

read_toml() {
    local file="$1" section="$2" key="$3"
    [ -f "$file" ] || return 0
    awk -v target="[$section]" -v key="$key" '
        /^\[/ {
            in_section = ($0 == target)
            next
        }
        in_section && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            value = $0
            sub(/^[^=]*=[[:space:]]*/, "", value)
            sub(/[[:space:]]*#.*$/, "", value)
            gsub(/^["'"'"']|["'"'"']$/, "", value)
            print value
            exit
        }
    ' "$file"
}

number() {
    case "$1" in
        ''|*[!0-9-]*) printf '%s' "${2:-0}" ;;
        *) printf '%s' "$1" ;;
    esac
}

height=$(number "$(read_toml "$umbriel_config" "appearance.title_bar" "height")" 28)
size=$(number "$(read_toml "$umbriel_config" "appearance.title_bar" "button_size")" -1)
gap=$(number "$(read_toml "$umbriel_config" "appearance.title_bar" "button_gap")" 8)
button_radius=$(number "$(read_toml "$umbriel_config" "appearance.title_bar" "button_corner_radius")" -1)
corner_radius=$(number "$(read_toml "$umbriel_config" "appearance" "corner_radius")" 10)

[ "$height" -lt 1 ] && height=28

# Mirrors titleBarButtonDiameter() in umbriel's src/scene/ssd_frame_geometry.cpp.
if [ "$size" -ge 0 ]; then
    [ "$size" -lt 1 ] && size=1
    [ "$size" -gt "$height" ] && size=$height
    diameter=$size
else
    diameter=$(( (height + 1) / 2 ))
    [ "$diameter" -lt 8 ] && diameter=8
    if [ $(( (height - diameter) % 2 )) -ne 0 ]; then
        if [ "$diameter" -gt 8 ]; then
            diameter=$(( diameter - 1 ))
        else
            diameter=$(( diameter + 1 ))
        fi
    fi
fi

[ "$button_radius" -lt 0 ] && button_radius=$corner_radius
if [ "$button_radius" -ge $(( diameter / 2 )) ]; then
    css_radius="9999px"
else
    css_radius="${button_radius}px"
fi

[ "$gap" -lt 0 ] && gap=8

# 派生值下限 15px：14 补到 15，15/16 保持
if [ "$diameter" -lt 15 ]; then
    diameter=15
fi
gap_half=$(( gap / 2 + 1 ))

mkdir -p "$(dirname "$input_file")"
sed \
    -e "s/__UMBRIEL_BUTTON_SIZE__/${diameter}/g" \
    -e "s/__UMBRIEL_BUTTON_RADIUS__/${css_radius}/g" \
    -e "s/__UMBRIEL_BUTTON_GAP_HALF__/${gap_half}/g" \
    "$template" > "$input_file"

printf '%s\n' "$input_file"

#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
template="$config_home/noctalia/templates/umbriel-gtk/gtk3-buttons.css"
umbriel_config="$config_home/umbriel/config.toml"
input_file="${XDG_CACHE_HOME:-$HOME/.cache}/noctalia/umbriel-gtk/gtk3-buttons-input.css"

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
padding=$(number "$(read_toml "$umbriel_config" "appearance.title_bar" "button_padding")" -1)
radius=$(number "$(read_toml "$umbriel_config" "appearance" "corner_radius")" 0)

darkly_rc="${XDG_CONFIG_HOME:-$HOME/.config}/darklyrc"
darkly_radius=$(number "$(read_toml "$darkly_rc" "Common" "CornerRadius")" 6)
darkly_button_height=$(number "$(read_toml "$darkly_rc" "Common" "ButtonHeight")" 1)
darkly_button_px=$(awk -v v="$darkly_button_height" 'BEGIN { h = v * 34; if (h < 0) h = 0; printf "%d", int(h + 0.5) }')
darkly_full_outline=$(read_toml "$darkly_rc" "Style" "FullOutline")
case "$darkly_full_outline" in true|True|TRUE|1) darkly_outline=1 ;; *) darkly_outline=0 ;; esac

darkly_sunken=$(read_toml "$darkly_rc" "Common" "SunkenEffect")
case "$darkly_sunken" in true|True|TRUE|1) darkly_sunken_css="inset 0 1px 2px rgba(0,0,0,0.45)" ;; *) darkly_sunken_css="none" ;; esac

darkly_new_checkbox=$(read_toml "$darkly_rc" "Common" "UseNewCheckBox")
case "$darkly_new_checkbox" in true|True|TRUE|1|"") darkly_check_radius=$darkly_radius ;; *) darkly_check_radius=0 ;; esac

darkly_menu_focus=$(read_toml "$darkly_rc" "Style" "MenuItemDrawStrongFocus")
case "$darkly_menu_focus" in false|False|FALSE|0) darkly_menu_focus_width=0 ;; *) darkly_menu_focus_width=1 ;; esac

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

[ "$gap" -lt 0 ] && gap=8
# 派生值下限 15px：与 GTK4/Zen 的按钮尺寸一致
if [ "$diameter" -lt 15 ]; then
    diameter=15
fi

# 与 umbriel 的 titleBarLayout() 对齐：左边距 = max(button_padding, 圆角内缩)，
# 按钮间距 = button_gap（GTK3 用左右 margin 各一半）。
vertical_inset=$(( (height - diameter) / 2 ))
[ "$vertical_inset" -lt 0 ] && vertical_inset=0
corner_inset=0
if [ "$radius" -gt "$vertical_inset" ]; then
    corner_inset=$(awk -v r="$radius" -v y="$vertical_inset" 'BEGIN { d = r - sqrt(y * (2 * r - y)); c = int(d); if (c < d) c++; print c + 1 }')
fi
literal_padding=$padding
[ "$literal_padding" -lt 0 ] && literal_padding=$vertical_inset
[ "$literal_padding" -lt "$corner_inset" ] && literal_padding=$corner_inset
# GTK3 按钮取最小尺寸。
diameter=$diameter
[ "$diameter" -lt 8 ] && diameter=8
# 按钮间距跟随 umbriel：偶数右比左多 1px（gap=8 → 左1右2），奇数左右相等（gap=9 → 左2右2）。
base=$(( gap / 2 - 3 ))
[ "$base" -lt 0 ] && base=0
if [ $(( gap % 2 )) -eq 0 ]; then
    gap_left=$base
    gap_right=$(( base + 1 ))
else
    gap_left=$(( base + 1 ))
    gap_right=$(( base + 1 ))
fi
literal_padding=$(( literal_padding - 3 ))
[ "$literal_padding" -lt 0 ] && literal_padding=0

# 按钮圆角跟随 umbriel：button_corner_radius=-1 时用窗口圆角，并限制在直径一半内。
button_radius=$(number "$(read_toml "$umbriel_config" "appearance.title_bar" "button_corner_radius")" -1)
if [ "$button_radius" -lt 0 ]; then
    button_radius=$radius
fi
if [ "$button_radius" -ge $(( diameter / 2 )) ]; then
    radius_css="9999px"
else
    radius_css="${button_radius}px"
fi


mkdir -p "$(dirname "$input_file")"
sed \
    -e "s/__UMBRIEL_BUTTON_SIZE__/${diameter}/g" \
    -e "s/__UMBRIEL_BUTTON_RADIUS__/${radius_css}/g" \
    -e "s/__DARKLY_CORNER_RADIUS__/${darkly_radius}/g" \
    -e "s/__DARKLY_BUTTON_HEIGHT__/${darkly_button_px}/g" \
    -e "s/__DARKLY_OUTLINE_WIDTH__/${darkly_outline}/g" \
    -e "s/__DARKLY_SUNKEN_SHADOW__/${darkly_sunken_css}/g" \
    -e "s/__DARKLY_CHECK_RADIUS__/${darkly_check_radius}/g" \
    -e "s/__DARKLY_MENU_FOCUS__/${darkly_menu_focus_width}/g" \
    -e "s/__UMBRIEL_BUTTON_PADDING__/${literal_padding}/g" \
    -e "s/__UMBRIEL_BUTTON_GAP_LEFT__/${gap_left}/g" \
    -e "s/__UMBRIEL_BUTTON_GAP_RIGHT__/${gap_right}/g" \
    "$template" > "$input_file"

extras_template="$config_home/noctalia/templates/umbriel-gtk/gtk3-extras.css"
if [ -f "$extras_template" ]; then
    sed \
        -e "s/__DARKLY_OUTLINE_WIDTH__/${darkly_outline}/g" \
        -e "s/__DARKLY_MENU_FOCUS__/${darkly_menu_focus_width}/g" \
        "$extras_template" > "$(dirname "$input_file")/gtk3-extras-input.css"
fi

printf '%s\n' "$input_file"

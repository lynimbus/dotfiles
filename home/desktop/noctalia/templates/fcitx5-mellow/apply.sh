#!/usr/bin/env bash
set -euo pipefail

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
theme_dir="$data_home/fcitx5/themes/noctalia-mellow"
classicui="$config_home/fcitx5/conf/classicui.conf"
umbriel_config="$config_home/umbriel/config.toml"
theme=noctalia-mellow

[ -f "$theme_dir/theme.conf" ] || exit 0

read_toml() {
    local file="$1" section="$2" key="$3"
    [ -f "$file" ] || return 0
    awk -v target="[$section]" -v key="$key" '
        /^\[/ { in_section = ($0 == target); next }
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

# Squared corners only when Umbriel's window corner radius is 0 or 1;
# otherwise keep mellow's default rounded corners.
corner=$(read_toml "$umbriel_config" "appearance" "corner_radius")
case "$corner" in
    0|1) radius=0 ;;
    *) radius=9.5 ;;
esac

for f in "$theme_dir/panel.svg" "$theme_dir/highlight.svg"; do
    [ -f "$f" ] || continue
    sed -i -E "s/rx=\"[0-9.]*\"/rx=\"$radius\"/g; s/ry=\"[0-9.]*\"/ry=\"$radius\"/g" "$f"
done

mkdir -p "$(dirname "$classicui")"
touch "$classicui"

if grep -q "^Theme=$theme$" "$classicui" && grep -q "^DarkTheme=$theme$" "$classicui"; then
    exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
awk -v t="$theme" '
    /^Theme=/ { print "Theme=" t; theme_set = 1; next }
    /^DarkTheme=/ { print "DarkTheme=" t; dark_set = 1; next }
    { print }
    END {
        if (!theme_set) print "Theme=" t
        if (!dark_set) print "DarkTheme=" t
    }
' "$classicui" >"$tmp"
cat "$tmp" >"$classicui"

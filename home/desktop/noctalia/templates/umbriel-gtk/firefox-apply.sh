#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}"
buttons_css="$cache/noctalia/umbriel-gtk/firefox-buttons.css"
import_line='@import url("umbriel-buttons.css");'

[ -f "$buttons_css" ] || exit 0

profiles=()
while IFS= read -r prefs; do
    profiles+=("$(dirname "$prefs")")
done < <(
    find \
        "$HOME/.mozilla/firefox" \
        "$HOME/.var/app/org.mozilla.firefox" \
        "$HOME/.librewolf" \
        "$HOME/.zen" \
        "$HOME/.var/app/app.zen_browser.zen" \
        "$config_home/zen" \
        -maxdepth 6 -type f -name prefs.js 2>/dev/null
)

[ "${#profiles[@]}" -eq 0 ] && exit 0

for profile in "${profiles[@]}"; do
    chrome="$profile/chrome"
    mkdir -p "$chrome"

    # Flatpak browsers cannot read the host cache dir, so keep the CSS next to
    # userChrome.css and import it with a relative URL.
    target="$chrome/umbriel-buttons.css"
    if ! cmp -s "$buttons_css" "$target"; then
        cat "$buttons_css" >"$target"
    fi

    user_chrome="$chrome/userChrome.css"
    touch "$user_chrome"
    # Drop the old absolute-path import from earlier versions.
    if grep -qF 'umbriel-gtk/firefox-buttons.css' "$user_chrome"; then
        sed -i '/umbriel-gtk\/firefox-buttons\.css/d' "$user_chrome"
    fi
    # Insert after the last @import so these rules load after Zen's own
    # userChrome styles and win the colour cascade.
    tmp="$(mktemp "${user_chrome}.tmp.XXXXXX")"
    awk -v imp="$import_line" '
        {
            if ($0 == imp) next
            lines[++n] = $0
            if ($0 ~ /^[[:space:]]*@import/) last = n
        }
        END {
            if (n == 0) {
                print imp
                exit
            }
            for (i = 1; i <= n; i++) {
                print lines[i]
                if (i == last) print imp
            }
            if (last == 0) print imp
        }
    ' "$user_chrome" >"$tmp"
    cat "$tmp" >"$user_chrome"
    rm -f "$tmp"

    user_js="$profile/user.js"
    touch "$user_js"
    if ! grep -q 'toolkit.legacyUserProfileCustomizations.stylesheets' "$user_js"; then
        [ -s "$user_js" ] && [ -n "$(tail -c1 "$user_js")" ] && echo >>"$user_js"
        printf '%s\n' 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >>"$user_js"
    fi
done

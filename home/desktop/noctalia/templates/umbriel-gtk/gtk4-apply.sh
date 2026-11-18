#!/usr/bin/env bash
set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
gtk_css="$config_dir/gtk-4.0/gtk.css"

mkdir -p "$(dirname "$gtk_css")"
touch "$gtk_css"

for import_line in '@import url("umbriel.css");' '@import url("umbriel-extras.css");'; do
    if grep -qxF "$import_line" "$gtk_css"; then
        continue
    fi

    tmp="$(mktemp "${gtk_css}.tmp.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT

    # Insert before the first real rule so the @import stays at the top of the file.
    awk -v imp="$import_line" '
        BEGIN { inserted = 0 }
        {
            line = $0
            if (!inserted &&
                line !~ /^[[:space:]]*$/ &&
                line !~ /^[[:space:]]*\/\*/ &&
                line !~ /^[[:space:]]*\*/ &&
                line !~ /^[[:space:]]*@import/) {
                print imp
                inserted = 1
            }
            print line
        }
        END { if (!inserted) print imp }
    ' "$gtk_css" >"$tmp"

    cat "$tmp" >"$gtk_css"
done

# Ask GTK to re-read its user stylesheet so running apps pick up the new colors.
touch "$gtk_css" 2>/dev/null || true

#!/usr/bin/env bash
# test_screenshot_config.sh — static checks on the chezmoi-managed swappy config.
#
# Why this suite exists: the Fedora port of the screenshot helper (satty is not
# packaged) originally passed `--early-exit` to swappy. That is not a swappy
# command-line switch — `swappy --help-all` lists only -h, -f/--file,
# -o/--output-file and -v/--version — so the "annotate, confirm once, get out of
# the way" flow satty provided via
# `--actions-on-enter="save-to-clipboard,exit"` silently disappeared. swappy's
# equivalent is the `early_exit` *key* in $XDG_CONFIG_HOME/swappy/config (or
# $HOME/.config/swappy/config). This suite pins that file down so the mistake
# cannot come back.
#
# Everything here is static: no Wayland session, no GUI, and nothing is ever
# written to the real ~/.config (the one dynamic check — chezmoi's source→target
# mapping — runs against a throwaway $HOME).
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

CFG_REL="home/chezmoi/dot_config/swappy/config"
CFG="${REPO_ROOT}/${CFG_REL}"
NIRI_CFG="${REPO_ROOT}/home/chezmoi/dot_config/niri/config.kdl"
SHOT_SCRIPT="${REPO_ROOT}/home/chezmoi/dot_local/bin/executable_screenshot"

# The nine keys swappy 1.5.1 asks for (`man swappy`, CONFIG FILE). Missing any
# of them makes the binary print "<key> is missing in <path> (<value>)" on every
# start, so the list is part of the contract, not a suggestion.
CFG_KEYS=(save_dir save_filename_format show_panel line_size text_size text_font paint_mode early_exit fill_shape)

# cfg_group <group> — print the key=value lines of one GLib key-file group.
# Comments (both GLib comment markers) and blank lines are dropped; anything
# before the first group header is ignored (that is invalid in a key file).
cfg_group() {
    awk -v want="$1" '
        { sub(/\r$/, "") }
        /^[[:space:]]*[#;]/ { next }
        /^[[:space:]]*$/ { next }
        /^[[:space:]]*\[/ {
            gsub(/^[[:space:]]*\[/, "")
            gsub(/\][[:space:]]*$/, "")
            inside = ($0 == want)
            next
        }
        inside { print }
    ' "$CFG"
}
cfg_default() { cfg_group Default; }

# cfg_get <key> — value of <key> inside [Default], whitespace-trimmed.
cfg_get() {
    cfg_default | awk -v k="$1" '
        {
            eq = index($0, "=")
            if (!eq) next
            key = substr($0, 1, eq - 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            if (key != k) next
            val = substr($0, eq + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
            print val
            exit
        }'
}

# normalize_home_path — collapse ~, $HOME and ${HOME} to a leading "~" and drop
# the trailing slash, so paths written in different styles can be compared.
# (sed instead of ${p//.../~}: bash tilde-expands a bare "~" replacement.)
normalize_home_path() {
    local p="$1"
    # The patterns are literal "${HOME}" / "$HOME" text inside the config file.
    # shellcheck disable=SC2016
    p="$(printf '%s' "$p" | sed -e 's#^\${HOME}#~#' -e 's#^\$HOME#~#' -e 's#/$##')"
    printf '%s' "$p"
}

t_title "swappy config — chezmoi source layout"

t_case "config source file exists (home/chezmoi/dot_config/swappy/config)"
assert_file_exists "swappy config" "$CFG"
if [[ ! -f "$CFG" ]]; then
    # Without the file every later grep would just spew "No such file"; fail
    # once, clearly, instead.
    printf '\nscreenshot_config: %d checks, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED" >&2
    exit 1
fi

t_case "source path is dot_config/swappy/config below home/chezmoi"
assert_eq "path below home/chezmoi" \
    "dot_config/swappy/config" "${CFG#"${REPO_ROOT}/home/chezmoi/"}"

t_case "chezmoi dot_config/ maps to ~/.config/"
# chezmoi convention: a `dot_` prefix on a path component becomes a literal
# leading dot, so dot_config/swappy/config installs as ~/.config/swappy/config.
rel="${CFG#"${REPO_ROOT}/home/chezmoi/"}"
assert_eq "target path" ".config/swappy/config" "$(printf '%s' "$rel" | sed -E 's#^dot_config/#.config/#')"

t_case "no stray chezmoi attribute prefixes on the file itself"
assert_eq "file component" "config" "$(basename "$rel")"

t_case "config header documents the deployed path ~/.config/swappy/config"
# shellcheck disable=SC2088 # literal target path, not a shell tilde to expand
assert_contains "deploy target in comments" "~/.config/swappy/config" "$CFG"

t_case "chezmoi resolves the source to ~/.config/swappy/config"
# Dynamic confirmation, but fully sandboxed: HOME/XDG_* point into a temp dir,
# so the user's real ~/.config is never read or written. Skipped when chezmoi
# is not installed (CI containers).
if command -v chezmoi >/dev/null 2>&1; then
    chezmoi_home="$(mktemp -d /tmp/aw-swappy-chezmoi-XXXXXX)"
    resolved="$(
        HOME="$chezmoi_home" \
        XDG_CONFIG_HOME="$chezmoi_home/.config" \
        XDG_DATA_HOME="$chezmoi_home/.local/share" \
        XDG_CACHE_HOME="$chezmoi_home/.cache" \
        chezmoi --source "${REPO_ROOT}/home/chezmoi" \
            source-path "$chezmoi_home/.config/swappy/config" 2>&1
    )"
    resolved_rc=$?
    rm -rf "$chezmoi_home"
    if [[ $resolved_rc -eq 0 ]]; then
        assert_eq "chezmoi source-path" "$CFG" "$resolved"
    else
        t_fail "chezmoi could not map ~/.config/swappy/config: $resolved"
    fi
else
    t_ok
    echo "    (chezmoi not installed — source→target mapping check skipped)" >&2
fi

t_title "swappy config — GLib key file shape"

t_case "exactly one group header and it is [Default]"
header_count="$(grep -cE '^[[:space:]]*\[' "$CFG")"
assert_eq "group header count" "1" "$header_count"
t_case "the group header is literally [Default]"
assert_eq "group header" "[Default]" "$(grep -E '^[[:space:]]*\[' "$CFG" | head -1 | tr -d '[:space:]')"

t_case "no keys before the first group header (GLib would reject them)"
assert_eq "pre-header assignment lines" "" \
    "$(awk '/^[[:space:]]*\[/ {seen=1} !seen && /^[[:space:]]*[^[:space:]#;]/ {print}' "$CFG")"

t_case "no CRLF line endings (parsed by GLib on every launch)"
if grep -q $'\r' "$CFG"; then t_fail "config contains CR bytes"; else t_ok; fi

t_case "file ends with a newline"
if [[ -z "$(tail -c 1 "$CFG")" ]]; then t_ok; else t_fail "config has no trailing newline"; fi

t_case "no chezmoi template actions in the key file"
assert_not_contains "chezmoi template delimiters" "{{" "$CFG"

t_case "every line inside [Default] is a well-formed key=value"
malformed="$(cfg_default | awk '
    {
        eq = index($0, "=")
        if (!eq) { print "no \"=\" : " $0; next }
        k = substr($0, 1, eq - 1)
        gsub(/[[:space:]]/, "", k)
        if (k !~ /^[A-Za-z_][A-Za-z0-9_]*$/) print "bad key: " $0
    }')"
assert_eq "malformed lines" "" "$malformed"

t_case "no duplicate keys (GLib treats them as a parse error)"
assert_eq "duplicate keys" "" \
    "$(cfg_default | sed -E 's/=.*//' | tr -d '[:space:]' | sort | uniq -d)"

t_case "the config parses as a GLib-compatible key file"
if command -v python3 >/dev/null 2>&1; then
    if python3 - "$CFG" <<'PY' 2>/tmp/aw-swappy-cfg.err
import configparser
import sys

parser = configparser.RawConfigParser(strict=True, allow_no_value=False)
with open(sys.argv[1], encoding="utf-8") as handle:
    parser.read_file(handle)
if "Default" not in parser:
    raise SystemExit("missing [Default] group")
PY
    then
        t_ok
    else
        t_fail "not a valid key file: $(cat /tmp/aw-swappy-cfg.err)"
    fi
else
    t_ok
    echo "    (python3 not installed — key-file parse check skipped)" >&2
fi

t_title "swappy config — required keys"

for key in "${CFG_KEYS[@]}"; do
    t_case "$key is present in [Default]"
    if cfg_default | grep -qE "^[[:space:]]*${key}[[:space:]]*="; then t_ok; else t_fail "$key missing from [Default]"; fi
done

t_case "no unexpected keys (swappy warns about nothing else, but keep it exact)"
extra="$(cfg_default | sed -E 's/[[:space:]]*=.*//' | sed -E 's/^[[:space:]]+//' | while read -r k; do
    [[ -z "$k" ]] && continue
    found=0
    for known in "${CFG_KEYS[@]}"; do [[ "$k" == "$known" ]] && found=1 && break; done
    (( found == 0 )) && printf '%s\n' "$k"
done)"
assert_eq "unexpected keys" "" "$extra"

t_title "swappy config — values"

t_case "early_exit is exactly true"
assert_eq "early_exit" "true" "$(cfg_get early_exit)"

t_case "early_exit=false never appears in the file (not even commented out)"
assert_not_contains "early_exit=false" "early_exit=false" "$CFG"

t_case "line_size is an integer within 1..50"
line_size="$(cfg_get line_size)"
if [[ "$line_size" =~ ^[0-9]+$ ]] && (( line_size >= 1 && line_size <= 50 )); then
    t_ok
else
    t_fail "line_size must be an integer 1..50, got [$line_size]"
fi

t_case "text_size is an integer within 10..50"
text_size="$(cfg_get text_size)"
if [[ "$text_size" =~ ^[0-9]+$ ]] && (( text_size >= 10 && text_size <= 50 )); then
    t_ok
else
    t_fail "text_size must be an integer 10..50, got [$text_size]"
fi

t_case "paint_mode is one of brush|text|rectangle|ellipse|arrow|blur"
paint_mode="$(cfg_get paint_mode)"
case "$paint_mode" in
    brush|text|rectangle|ellipse|arrow|blur) t_ok ;;
    *) t_fail "paint_mode must be brush|text|rectangle|ellipse|arrow|blur, got [$paint_mode]" ;;
esac

for bool_key in show_panel fill_shape; do
    t_case "$bool_key is a bare boolean (true|false)"
    bool_val="$(cfg_get "$bool_key")"
    if [[ "$bool_val" =~ ^(true|false)$ ]]; then t_ok; else t_fail "$bool_key must be true|false, got [$bool_val]"; fi
done

t_case "text_font is a non-empty Pango font description"
text_font="$(cfg_get text_font)"
if [[ -n "$text_font" ]]; then t_ok; else t_fail "text_font is empty"; fi
t_case "text_font has no shell/pango metacharacters that would break the parser"
if [[ "$text_font" =~ ^[A-Za-z0-9][A-Za-z0-9\ ,_-]*$ ]]; then t_ok; else t_fail "suspicious text_font [$text_font]"; fi

t_case "save_dir points at Pictures/Screenshots"
save_dir="$(cfg_get save_dir)"
assert_contains "Pictures/Screenshots" "Pictures/Screenshots" "$save_dir"

t_case "save_dir is home-relative (uses \$HOME, \${HOME} or ~, never /home/<user>)"
# shellcheck disable=SC2016 # matching the literal "$HOME" token in the file
if [[ "$save_dir" == *'$HOME'* || "$save_dir" == *'${HOME}'* || "$save_dir" == '~'* ]]; then t_ok; else t_fail "save_dir must be home-relative, got [$save_dir]"; fi
t_case "save_dir has no hard-coded /home/ path"
assert_not_contains "/home/" "/home/" "$save_dir"
t_case "save_dir has no hard-coded /root path"
assert_not_contains "/root/" "/root/" "$save_dir"

t_case "save_dir matches niri's screenshot-path directory"
if [[ -f "$NIRI_CFG" ]]; then
    niri_shot="$(sed -n 's/^[[:space:]]*screenshot-path[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$NIRI_CFG" | head -1)"
    if [[ -z "$niri_shot" ]]; then
        t_ok
        echo "    (niri screenshot-path not found — cross-check skipped)" >&2
    else
        niri_dir="$(dirname "$niri_shot")"
        assert_eq "screenshot directory (niri vs swappy)" \
            "$(normalize_home_path "$niri_dir")" "$(normalize_home_path "$save_dir")"
    fi
else
    t_ok
    echo "    (niri config absent — cross-check skipped)" >&2
fi

t_case "save_filename_format is a .png strftime template"
filename_format="$(cfg_get save_filename_format)"
if [[ "$filename_format" == *.png && "$filename_format" == *%* ]]; then t_ok; else t_fail "save_filename_format must be a .png strftime template, got [$filename_format]"; fi
t_case "save_filename_format carries a date and a time directive"
if [[ "$filename_format" == *%Y* && "$filename_format" == *%H* && "$filename_format" == *%M* && "$filename_format" == *%S* ]]; then
    t_ok
else
    t_fail "save_filename_format needs %Y/%H/%M/%S, got [$filename_format]"
fi
t_case "save_filename_format only uses directives swappy can parse"
unexpected_directives="$(printf '%s' "$filename_format" | grep -oE '%[^YmdHMS%]' || true)"
assert_eq "unexpected strftime directives" "" "$unexpected_directives"

t_case "save_filename_format filename shape agrees with niri's screenshot-path"
if [[ -f "$NIRI_CFG" && -n "${niri_shot:-}" ]]; then
    assert_eq "filename template (niri vs swappy)" "$(basename "$niri_shot")" "$filename_format"
else
    t_ok
    echo "    (niri screenshot-path not found — cross-check skipped)" >&2
fi

t_case "the helper script writes into the same Pictures/Screenshots tree"
# The script resolves PICTURES through xdg-user-dir, so only the leaf directory
# is asserted here; the exact path lives in test_screenshot.sh.
if [[ -f "$SHOT_SCRIPT" ]]; then
    assert_contains "helper writes to Screenshots/" "Screenshots" "$SHOT_SCRIPT"
else
    t_ok
    echo "    (screenshot helper absent — cross-check skipped)" >&2
fi

t_title "swappy config — anti-regression comments and CLI surface"

t_case "comments pin early_exit as a config key"
comment_text="$(grep -E '^[[:space:]]*#' "$CFG" || true)"
assert_contains "comment mentions early_exit" "early_exit" "$comment_text"
t_case "comments spell out the invalid --early-exit CLI option"
assert_contains "comment mentions --early-exit" "--early-exit" "$comment_text"

t_case "comments say early_exit is a config key (not a CLI switch)"
if grep -qiE 'early_exit.{0,40}(config[[:space:]]+key|config[[:space:]]+option|configuration key)' <<<"$comment_text"; then
    t_ok
else
    t_fail "no comment explains that early_exit is a config key"
fi
t_case "comments say --early-exit is not a valid CLI option"
if grep -qiE -e '--early-exit.{0,80}(not[[:space:]]+(a[[:space:]]+)?(valid|recognised|recognized|supported|real)[[:space:]]+(cli[[:space:]]+)?(option|switch|flag)|invalid|no such|does not exist|isn.t)' <<<"$comment_text"; then
    t_ok
else
    t_fail "no comment says --early-exit is not a valid CLI option"
fi

t_case "swappy --help-all does not advertise --early-exit (it is config-only)"
if command -v swappy >/dev/null 2>&1; then
    help_out="$(swappy --help-all 2>&1 || true)"
    assert_not_contains "declared CLI switch" "--early-exit" "$help_out"
    t_case "swappy still advertises the options the helper uses"
    assert_contains "swappy advertises -f/--file" "--file" "$help_out"
    t_case "swappy advertises -o/--output-file"
    assert_contains "swappy advertises -o/--output-file" "--output-file" "$help_out"
else
    t_ok
    echo "    (swappy not installed — CLI surface check skipped)" >&2
fi

t_case "swappy binary knows the early_exit key (config-only, as documented)"
swappy_bin="$(command -v swappy 2>/dev/null || true)"
if [[ -n "$swappy_bin" && -r "$swappy_bin" ]]; then
    if grep -aq 'early_exit' "$swappy_bin"; then t_ok; else t_fail "binary does not reference the early_exit config key"; fi
else
    t_ok
    echo "    (swappy binary not readable — key-name check skipped)" >&2
fi

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "screenshot_config: ${TESTS_RUN} checks, 0 failed" >&2
    exit 0
else
    echo "screenshot_config: ${TESTS_RUN} checks, ${TESTS_FAILED} failed" >&2
    exit 1
fi

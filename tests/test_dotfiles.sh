#!/usr/bin/env bash
# test_dotfiles.sh — static checks on the chezmoi-managed user config.
#
# These catch typos/bad keys that only surface when a shell or tool actually
# starts, which is exactly how two real bugs shipped:
#   * fish/config.fish called `fish_vi_keybindings` (missing underscore) — not
#     a fish function, so every interactive shell printed
#     "fish: Unknown command: fish_vi_keybindings";
#   * jj/config.toml.tmpl still set the boolean `git.sign-on-push`, deprecated
#     in jj 0.47, so every jj/jjui invocation printed a deprecation warning.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

FISH_DIR="${REPO_ROOT}/home/chezmoi/dot_config/fish"
JJ_TMPL="${REPO_ROOT}/home/chezmoi/dot_config/jj/config.toml.tmpl"

# The chezmoi jj template is Go-templated, so strip the template actions to get
# something parseable as a plain TOML file for syntax checking.
strip_template() { sed -E 's/\{\{[^}]*\}\}/x/g' "$1"; }

t_title "chezmoi user config"

t_case "fish config is syntactically valid"
if command -v fish >/dev/null 2>&1; then
    if fish -n "${FISH_DIR}/config.fish" 2>/tmp/aw-fish.err; then t_ok; else t_fail "$(cat /tmp/aw-fish.err)"; fi
else
    t_ok
    echo "    (fish not installed — syntax check skipped)" >&2
fi

t_case "jjmsg function is syntactically valid"
if command -v fish >/dev/null 2>&1; then
    if fish -n "${FISH_DIR}/functions/jjmsg.fish" 2>/tmp/aw-fish.err; then t_ok; else t_fail "$(cat /tmp/aw-fish.err)"; fi
else
    t_ok
fi

t_case "fish uses the real vi keybinding function name"
# `fish_vi_keybindings` (no underscore) is not a function in any fish release.
# Only check non-comment lines: the explanatory comment above the call names
# the typo on purpose, so a whole-file grep would match that prose.
fish_cmds="$(grep -vE '^[[:space:]]*#' "${FISH_DIR}/config.fish")"
assert_contains "fish_vi_key_bindings" "fish_vi_key_bindings" "$fish_cmds"
assert_not_contains "no fish_vi_keybindings typo in executable lines" \
    "fish_vi_keybindings" "$fish_cmds"

t_case "fish interactive init actually loads in fish"
if command -v fish >/dev/null 2>&1; then
    out="$(fish -i -c 'functions -q fish_vi_key_bindings; and echo ok' 2>&1 | tr -d '\033')"
    if grep -q ok <<<"$out"; then t_ok; else t_fail "interactive init did not load: $out"; fi
else
    t_ok
fi

t_case "fcitx5 profile is create_private_ (self-rewriting app)"
# fcitx5 rewrites ~/.config/fcitx5/profile every run: it strips comments and
# chmods the file 0600. A plain `dot_config/.../profile` therefore shows
# permanent chezmoi drift (and a mode-only diff). `create_private_` seeds it
# once, forces mode 0600 and then leaves the app's own output alone.
assert_file_exists "create_private_profile" \
    "${REPO_ROOT}/home/chezmoi/dot_config/fcitx5/create_private_profile"
# A plain `profile` entry would be re-applied over fcitx5's own output forever.
if [[ -e "${REPO_ROOT}/home/chezmoi/dot_config/fcitx5/profile" ]]; then
    t_fail "plain profile file shadows create_private_profile"
else
    t_ok
fi

t_case "jj config does not use the deprecated git.sign-on-push boolean"
assert_not_contains "no boolean key" "sign-on-push = true" "$JJ_TMPL"
assert_contains "uses revsets.git-sign-on-push" "git-sign-on-push" "$JJ_TMPL"

t_case "jj template renders to parseable TOML"
if command -v python3 >/dev/null 2>&1 && python3 -c 'import tomllib' 2>/dev/null; then
    tmp="$(mktemp)"
    strip_template "$JJ_TMPL" >"$tmp"
    if python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1],"rb"))' "$tmp" 2>/tmp/aw-toml.err; then
        t_ok
    else
        t_fail "rendered jj config is not valid TOML: $(cat /tmp/aw-toml.err)"
    fi
    rm -f "$tmp"
else
    t_ok
fi

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "dotfiles: ${TESTS_RUN} checks, 0 failed" >&2
    exit 0
else
    echo "dotfiles: ${TESTS_RUN} checks, ${TESTS_FAILED} failed" >&2
    exit 1
fi

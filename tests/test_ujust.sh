#!/usr/bin/env bash
# test_ujust.sh — the image's ujust recipes must actually be reachable.
#
# Regression guard for a real image bug: the recipes shipped as
# system_files/usr/share/ublue-os/just/99-atomic-workstation.just, but
# /usr/share/ublue-os/justfile imports its recipe files EXPLICITLY and only
# reserves ONE extension point for custom images:
#
#     import? "/usr/share/ublue-os/just/60-custom.just"
#
# A file under any other name is never imported, so `ujust atomic-ws-doctor`
# failed with "justfile does not contain recipe" no matter how correct its
# contents were. These tests pin that down without needing podman or a build.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

JUST_SRC="$REPO_ROOT/system_files/usr/share/ublue-os/just"
RECIPE_FILE="$JUST_SRC/60-custom.just"

t_title "ujust recipes"

if ! command -v just >/dev/null 2>&1; then
    echo "just is not installed — skipping the ujust suite" >&2
    exit 0
fi

t_case "recipes live at the one path the base justfile imports"
assert_file_exists "60-custom.just present" "$RECIPE_FILE"
# Any *.just in the image tree other than 60-custom.just is dead code: the
# base justfile never imports it. Fail loudly so a rename cannot reintroduce
# the bug silently.
stray="$(find "$JUST_SRC" -maxdepth 1 -type f -name '*.just' ! -name '60-custom.just' 2>/dev/null)"
if [[ -z "$stray" ]]; then
    t_ok
else
    t_fail "unimportable recipe file(s) under $JUST_SRC: $stray"
fi

t_case "the recipe file parses on its own"
out="$(just -f "$RECIPE_FILE" --list 2>&1)"
if [[ $? -eq 0 ]]; then t_ok; else t_fail "just --list failed: $out"; fi

t_case "every documented atomic-ws-* recipe resolves"
missing=""
for recipe in \
    atomic-ws-doctor atomic-ws-sync atomic-ws-restore atomic-ws-user-apps \
    atomic-ws-set-shell-fish atomic-ws-ollama-pull atomic-ws-sudo-nopasswd; do
    just -f "$RECIPE_FILE" --show "$recipe" >/dev/null 2>&1 || missing="$missing $recipe"
done
if [[ -z "$missing" ]]; then t_ok; else t_fail "unresolvable recipe(s):$missing"; fi

t_case "recipes are grouped so ujust can list them"
assert_contains "atomic-workstation group" "[group('atomic-workstation')]" "$RECIPE_FILE"

t_case "set-shell-fish does not depend on the missing chsh"
# Bazzite's util-linux ships without /usr/bin/chsh (rpm -V reports it missing),
# so a recipe that only calls `chsh` fails with command-not-found. Guard it.
assert_contains "falls back to usermod" "usermod -s" "$RECIPE_FILE"
assert_contains "checks for chsh first" "command -v chsh" "$RECIPE_FILE"

t_case "ollama-pull targets the ollama service account"
assert_contains "sudo -u ollama" "sudo -u ollama" "$RECIPE_FILE"

t_case "the base justfile's custom slot matches the file we ship"
# If the running host has the base justfile (any Bazzite), assert it imports
# exactly this path; otherwise the check is informational.
if [[ -f /usr/share/ublue-os/justfile ]]; then
    if grep -qF 'import? "/usr/share/ublue-os/just/60-custom.just"' /usr/share/ublue-os/justfile; then
        t_ok
    else
        t_fail "base justfile does not import 60-custom.just (upstream changed the slot?)"
    fi
else
    t_ok
    echo "    (no base justfile on this host — slot check skipped)" >&2
fi

t_title "doctor runs from the repo"
t_case "doctor.sh is executable and syntactically valid"
assert_file_exists "scripts/doctor.sh" "$REPO_ROOT/scripts/doctor.sh"
if bash -n "$REPO_ROOT/scripts/doctor.sh" 2>/dev/null; then t_ok; else t_fail "bash -n failed"; fi

# ── justfile header consolidation + recipe surface ──────────────────────────
JUSTFILE="$REPO_ROOT/justfile"

t_title "justfile recipe surface"

t_case "just -f justfile --list succeeds"
( cd "$REPO_ROOT" && just -f justfile --list >/dev/null 2>&1 )
assert_rc 0 "just --list"

t_case "just --summary still lists the same 12 recipe names"
assert_eq "recipe names" \
    "brew-seed flatpak-seed image-build image-check image-clean image-generate-build-tags image-generate-default-tag image-name image-ostree-rechunk image-rechunk image-tag-images user-apps" \
    "$( cd "$REPO_ROOT" && just -f justfile --summary 2>/dev/null )"

t_case "60-custom.just keeps its why-comment and recipe list"
assert_contains "filename why-comment" 'The FILE NAME is load-bearing.' "$RECIPE_FILE"
assert_eq "ujust recipe names" \
    "atomic-ws-doctor atomic-ws-ollama-pull atomic-ws-qq-migrate atomic-ws-restore atomic-ws-set-shell-fish atomic-ws-sudo-nopasswd atomic-ws-sync atomic-ws-user-apps" \
    "$( cd "$REPO_ROOT" && just -f "$RECIPE_FILE" --summary 2>/dev/null )"

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "ujust: ${TESTS_RUN} checks, 0 failed" >&2
    exit 0
else
    echo "ujust: ${TESTS_RUN} checks, ${TESTS_FAILED} failed" >&2
    exit 1
fi

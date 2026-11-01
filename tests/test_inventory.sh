#!/usr/bin/env bash
# test_inventory.sh — the unified entry point (scripts/inventory.sh):
# argument parsing, profile handling and the no-empty-argument contract.
# These are regression tests for real bugs found in review:
#   * "restore --prune" used to treat "--prune" as the profile name
#   * "${args[@]:-}" injected an empty argument, so "restore <profile>"
#     failed with "only one profile argument allowed"
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

INV="${REPO_ROOT}/scripts/inventory.sh"

t_title "inventory.sh entry point"

t_setup
# one app installed so a capture has something to record
flatpak remote-add --if-not-exists --user flathub https://example.com/flathub/ >/dev/null 2>&1
flatpak install --user --assumeyes flathub org.inv.App//stable >/dev/null 2>&1

t_case "capture writes an inventory for the given profile"
out=$(bash "$INV" capture "prof1" 2>&1)
assert_file_exists "flatpak inventory" "${REPO_ROOT}/apps/flatpak/inventory/prof1.json"
assert_contains "reports completion" "capture complete" "$out"

t_case "profile argument is forwarded to restore (no empty arg injected)"
out=$(bash "$INV" restore "prof1" 2>&1)
assert_contains "uses prof1" "profile 'prof1'" "$out"
assert_not_contains "no argument-parsing failure" "only one profile argument allowed" "$out"

t_case "restore --prune is parsed as a flag, not as the profile"
out=$(bash "$INV" restore "prof1" --prune --dry-run 2>&1)
assert_not_contains "no bogus profile named --prune" "profile '--prune'" "$out"
assert_contains "prune considered" "prune" "$out"

t_case "restore --dry-run changes nothing"
before=$(flatpak list --app --columns=application --user | sort)
bash "$INV" restore "prof1" --dry-run >/dev/null 2>&1
after=$(flatpak list --app --columns=application --user | sort)
assert_eq "installed set unchanged" "$before" "$after"

t_case "unknown flag is rejected with usage hint"
out=$(bash "$INV" restore --bogus 2>&1)
# assert_rc reads $? of the command substitution above — do not consume it
assert_rc 1 "exits 1 on unknown flag"
assert_contains "explains the flag problem" "unknown option" "$out"

t_case "unknown subcommand prints usage and fails"
out=$(bash "$INV" frobnicate 2>&1)
assert_rc 1 "exits 1 on unknown command"
assert_contains "prints usage" "usage:" "$out"

t_case "status works with a profile that has an inventory"
out=$(bash "$INV" status "prof1" 2>&1)
assert_contains "flatpak compared" "flatpak" "$out"
assert_not_contains "no crash" "Traceback" "$out"

t_case "sync reports the git state of the inventory files"
out=$(bash "$INV" sync "prof1" 2>&1)
assert_contains "mentions inventory state" "inventory" "$out"

t_teardown
rm -f "${REPO_ROOT}/apps/flatpak/inventory/prof1.json"
rm -rf "${REPO_ROOT}/apps/brew/inventory/prof1" "${REPO_ROOT}/containers/inventory/prof1.json"

printf '\ninventory.sh: %d checks, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED" >&2
exit "$TESTS_FAILED"

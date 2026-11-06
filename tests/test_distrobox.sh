#!/usr/bin/env bash
# test_distrobox.sh — container inventory capture/restore tests using mock-distrobox.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

CAPTURE="${REPO_ROOT}/containers/capture.sh"
RESTORE="${REPO_ROOT}/containers/restore.sh"

t_title "distrobox containers"

t_setup
INV="$ATOMIC_WS_ROOT/containers/inventory/${WORKSTATION_PROFILE}.json"
rm -f "$INV"

t_case "capture skips cleanly when distrobox is absent"
t_disable_mock distrobox
out=$(bash "$CAPTURE" 2>&1)
assert_contains "skip message" "distrobox is not installed" "$out"
t_enable_mock distrobox

t_case "capture records name, image and bootstrap script presence"
distrobox assemble create --file "${REPO_ROOT}/containers/distrobox.ini" >/dev/null 2>&1
bash "$CAPTURE" >/dev/null 2>&1
assert_contains "name recorded" '"name": "fedora-dev"' "$INV"
assert_contains "image recorded" 'fedora-toolbox:42' "$INV"
assert_contains "bootstrap recorded" '"bootstrap": "containers/bootstrap/fedora-dev.sh"' "$INV"

t_case "capture is idempotent"
cp "$INV" "$T_SANDBOX/inv-before"
bash "$CAPTURE" >/dev/null 2>&1
if cmp -s "$T_SANDBOX/inv-before" "$INV"; then t_ok; else t_fail "re-capture changed the file"; fi

t_case "restore creates missing containers without touching existing ones"
rm -rf "$MOCK_STATE/distrobox"
out=$(bash "$RESTORE" 2>&1)
assert_contains "container created" "Created fedora-dev" "$out"
assert_contains "bootstrap ran" "bootstrap" "$out"

t_case "restore is idempotent — existing containers are skipped"
out=$(bash "$RESTORE" 2>&1)
assert_contains "existing skipped" "Skipping existing container fedora-dev" "$out"
assert_not_contains "no re-bootstrap" "bootstrapping new container" "$out"

t_case "restore skips cleanly when distrobox is absent"
t_disable_mock distrobox
out=$(bash "$RESTORE" 2>&1)
assert_contains "skip message" "distrobox is not installed" "$out"
t_enable_mock distrobox

t_teardown
rm -f "${REPO_ROOT}/containers/inventory/testbox.json"

printf '\ndistrobox: %d checks, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED" >&2
exit "$TESTS_FAILED"

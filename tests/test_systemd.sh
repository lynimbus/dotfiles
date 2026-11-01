#!/usr/bin/env bash
# test_systemd.sh — unit file validation and timer behaviour.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

UNITS="$REPO_ROOT/system/systemd/user"

t_title "systemd user units"

t_case "service file is a valid systemd unit"
verify_out=$(systemd-analyze verify "$UNITS/atomic-workstation-inventory.service" 2>&1)
if grep -v 'Invalid URL' <<<"$verify_out" | grep -q .; then
    t_fail "service verify failed: $verify_out"
else
    t_ok
fi

t_case "timer file is a valid systemd unit"
verify_out=$(systemd-analyze verify "$UNITS/atomic-workstation-inventory.timer" 2>&1)
if [[ -z "$verify_out" ]]; then t_ok; else t_fail "timer verify: $verify_out"; fi

t_case "service runs capture as user, without root or push"
exec_line=$(grep '^ExecStart=' "$UNITS/atomic-workstation-inventory.service")
assert_contains "runs inventory.sh capture" "inventory.sh capture" "$exec_line"
assert_not_contains "ExecStart never calls sync/push" "sync" "$exec_line"
assert_not_contains "no sudo" "sudo" "$exec_line"

t_case "timer has Persistent=true and hourly cadence"
timer="$(cat "$UNITS/atomic-workstation-inventory.timer")"
assert_contains "hourly cadence" "OnUnitActiveSec=1h" "$timer"
assert_contains "catches up after sleep" "Persistent=true" "$timer"
assert_contains "enabled via timers.target" "WantedBy=timers.target" "$timer"

t_case "failure logging: output explicitly goes to the journal"
svc="$(cat "$UNITS/atomic-workstation-inventory.service")"
assert_contains "stdout to journal" "StandardOutput=journal" "$svc"
assert_contains "stderr to journal" "StandardError=journal" "$svc"

t_case "install-user-timer.sh copies units to ~/.config/systemd/user"
T2="$(mktemp -d)"
HOME="$T2" bash "${REPO_ROOT}/scripts/install-user-timer.sh" >/dev/null 2>&1 || true
for u in atomic-workstation-inventory.service atomic-workstation-inventory.timer; do
    assert_file_exists "installed: $u" "$T2/.config/systemd/user/$u"
done
rm -rf "$T2"

printf '\nsystemd: %d checks, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED" >&2
exit "$TESTS_FAILED"

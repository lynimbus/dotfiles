#!/usr/bin/env bash
# test_systemd.sh — unit file validation and timer behaviour.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

UNITS="$REPO_ROOT/system/systemd/user"

t_title "systemd user units"

# The shipped unit points ExecStart at %h/dotfiles/… (the documented clone
# location). `systemd-analyze verify` resolves %h and then insists the binary
# exists, so verifying the committed file only passes on a machine whose repo
# happens to be at ~/dotfiles. Verify an otherwise-identical copy whose
# ExecStart points at this checkout instead: that still exercises every other
# directive, and does not depend on where the repo lives.
verify_unit() { # verify_unit <unit file> → prints whatever systemd complains about
    local unit="$1" tmp
    tmp="$(mktemp -d)"
    sed "s|%h/dotfiles|${REPO_ROOT}|g" "$unit" >"${tmp}/$(basename "$unit")"
    systemd-analyze verify "${tmp}/$(basename "$unit")" 2>&1
    rm -rf "$tmp"
}

t_case "service file is a valid systemd unit"
if [[ ! -x "${REPO_ROOT}/scripts/inventory.sh" ]]; then
    t_fail "scripts/inventory.sh is not executable — ExecStart would fail"
else
    verify_out=$(verify_unit "$UNITS/atomic-workstation-inventory.service")
    if grep -v 'Invalid URL' <<<"$verify_out" | grep -q .; then
        t_fail "service verify failed: $verify_out"
    else
        t_ok
    fi
fi

t_case "timer file is a valid systemd unit"
verify_out=$(verify_unit "$UNITS/atomic-workstation-inventory.timer")
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

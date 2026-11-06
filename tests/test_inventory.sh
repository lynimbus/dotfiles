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

# Ablation contracts: the shared library keeps its live helpers (and their
# behaviour), loses the two unused ones, and the scripts lose only comments
# that restated the code.
t_case "common.sh still exports the helper contract with unchanged behaviour"
COMMON="${REPO_ROOT}/scripts/lib/common.sh"
HELPER_REPO="${T_SANDBOX}/common-repo"
mkdir -p "$HELPER_REPO"
git -C "$HELPER_REPO" init -q
helper_out=$(
    ATOMIC_WS_ROOT="$HELPER_REPO" WORKSTATION_PROFILE=helperbox NO_COLOR=1 \
        bash -c '
            source "$1" || exit 99
            for fn in aw_ok aw_warn aw_error aw_info aw_step aw_die aw_have \
                      aw_profile aw_git aw_git_dirty aw_git_in_merge aw_confirm; do
                declare -F "$fn" >/dev/null || printf "MISSING:%s\n" "$fn"
            done
            d1="aw_inventory""_dirs"
            d2="aw_confirm""_destructive"
            for fn in "$d1" "$d2"; do
                declare -F "$fn" >/dev/null && printf "DEAD:%s\n" "$fn"
            done
            printf "profile=%s\n" "$(aw_profile)"
            if aw_have bash; then echo "have=1"; else echo "have=0"; fi
            if AW_DISABLE_CMDS=bash aw_have bash; then echo "disabled=1"; else echo "disabled=0"; fi
            if AW_ASSUME_YES=1 aw_confirm "go?"; then echo "confirm_yes=1"; else echo "confirm_yes=0"; fi
            if aw_confirm "go?" 2>/dev/null; then echo "confirm_no=1"; else echo "confirm_no=0"; fi
            printf "dirty_clean=%s\n" "$(aw_git_dirty)"
            : >"$ATOMIC_WS_ROOT/untracked"
            printf "dirty_changed=%s\n" "$(aw_git_dirty)"
        ' _ "$COMMON" 2>/dev/null
)
assert_not_contains "all required helpers are still defined" "MISSING:" "$helper_out"
assert_not_contains "the ablated helpers are absent" "DEAD:" "$helper_out"
assert_contains "aw_profile honours WORKSTATION_PROFILE" "profile=helperbox" "$helper_out"
assert_contains "aw_have finds a present command" "have=1" "$helper_out"
assert_contains "AW_DISABLE_CMDS still hides a command" "disabled=0" "$helper_out"
assert_contains "aw_confirm honours AW_ASSUME_YES" "confirm_yes=1" "$helper_out"
assert_contains "aw_confirm still defaults to no" "confirm_no=0" "$helper_out"
assert_contains "aw_git_dirty reports a clean tree" "dirty_clean=0" "$helper_out"
assert_contains "aw_git_dirty reports untracked changes" "dirty_changed=1" "$helper_out"

t_case "--list output is unchanged"
list_out="$(bash "${REPO_ROOT}/scripts/install-user-apps.sh" --list 2>/dev/null)"
expected_list=$'magpie     v0.1.2909    binary    https://github.com/yetone/magpie/releases/download/v0.1.2909/magpie-linux-amd64\nghostty    v1.4.0       appimage  https://github.com/pkgforge-dev/ghostty-appimage/releases/download/v1.4.0/Ghostty-1.4.0-x86_64.AppImage\nopengrep   v1.33.1      binary    https://github.com/opengrep/opengrep/releases/download/v1.33.1/opengrep_manylinux_x86\nr8         9.5.28       jar       https://dl.google.com/android/maven2/com/android/tools/r8/9.5.28/r8-9.5.28.jar\nmygo       v0.7.3       goinstall github.com/egoist/mygo/cmd/mygo@v0.7.3\nrime-ice                gitdata   https://github.com/iDvel/rime-ice'
assert_eq "--list prints the same manifest" "$expected_list" "$list_out"

t_teardown
rm -f "${REPO_ROOT}/apps/flatpak/inventory/prof1.json"
rm -rf "${REPO_ROOT}/apps/brew/inventory/prof1" "${REPO_ROOT}/containers/inventory/prof1.json"

printf '\ninventory.sh: %d checks, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED" >&2
exit "$TESTS_FAILED"

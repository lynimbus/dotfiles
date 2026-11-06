#!/usr/bin/env bash
# lib.sh — tiny test framework for atomic-workstation (sourced by test files).
set -uo pipefail

TESTS_RUN=0
TESTS_FAILED=0

t_title() { printf '\n== %s ==\n' "$*" >&2; }
t_case() {
    TESTS_RUN=$((TESTS_RUN + 1))
    printf '  · %s ' "$*" >&2
}
t_ok() { printf 'OK\n' >&2; }
t_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'FAIL: %s\n' "$*" >&2
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ -f "$haystack" ]]; then haystack="$(cat "$haystack")"; fi
    if grep -qF -- "$needle" <<<"$haystack"; then t_ok; else t_fail "$desc: missing [$needle]"; fi
}
assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ -f "$haystack" ]]; then haystack="$(cat "$haystack")"; fi
    if grep -qF -- "$needle" <<<"$haystack"; then t_fail "$desc: unexpected [$needle]"; else t_ok; fi
}
assert_eq() {
    if [[ "$2" == "$3" ]]; then t_ok; else t_fail "$1: expected [$2] got [$3]"; fi
}
assert_file_exists() {
    if [[ -e "$2" ]]; then t_ok; else t_fail "$1: $2 does not exist"; fi
}
# Capture $? first: assert_rc must be called immediately after the command.
assert_rc() {
    local want="$1" got="$?" desc="$2"
    if [[ "$got" == "$want" ]]; then t_ok; else t_fail "$desc: expected rc=$want, got rc=$got"; fi
}

# Sandbox with mocks installed under their REAL names (flatpak/brew/distrobox).
T_SANDBOX=""
t_setup() {
    T_SANDBOX="$(mktemp -d /tmp/aw-test-XXXXXX)"
    mkdir -p "$T_SANDBOX/home" "$T_SANDBOX/bin"
    t_enable_mock flatpak
    t_enable_mock brew
    t_enable_mock distrobox
    export MOCK_STATE="$T_SANDBOX/mock"
    export HOME="$T_SANDBOX/home"
    export PATH="$T_SANDBOX/bin:${PATH}"
    export WORKSTATION_PROFILE="testbox"
    export ATOMIC_WS_ROOT="${REPO_ROOT}"
    export NO_COLOR=1
}
# Mocks are installed under the real name; `disable` must ALSO make the real
# binary invisible, otherwise a machine that has brew/distrobox in PATH (every
# Bazzite host) makes the "tool absent" cases fail — and, worse, the scripts
# fall through to the real tool (real distrobox would create podman state in
# the sandbox HOME). A PATH cannot hide /usr/bin/distrobox, so aw_have() in
# scripts/lib/common.sh honours AW_DISABLE_CMDS for exactly this purpose.
t_enable_mock() {
    ln -sf "${REPO_ROOT}/tests/fixtures/bin/mock-$1" "$T_SANDBOX/bin/$1"
    t_undisable_cmd "$1"
}
t_disable_mock() {
    rm -f "$T_SANDBOX/bin/$1"
    t_disable_cmd "$1"
}
t_disable_cmd() {
    local cur=" ${AW_DISABLE_CMDS:-} "
    [[ "$cur" == *" $1 "* ]] || export AW_DISABLE_CMDS="${AW_DISABLE_CMDS:+${AW_DISABLE_CMDS} }$1"
}
t_undisable_cmd() {
    local out="" c
    for c in ${AW_DISABLE_CMDS:-}; do
        [[ "$c" == "$1" ]] && continue
        out="${out:+$out }$c"
    done
    export AW_DISABLE_CMDS="$out"
}
t_teardown() {
    if [[ -n "$T_SANDBOX" ]]; then
        # Rootless podman/overlay leaves root-owned files behind if a test ever
        # reaches the real engine; brute-force the permissions before removing.
        chmod -R u+rwX "$T_SANDBOX" 2>/dev/null || true
        rm -rf "$T_SANDBOX" 2>/dev/null || true
    fi
    unset MOCK_STATE WORKSTATION_PROFILE AW_DISABLE_CMDS 2>/dev/null || true
}

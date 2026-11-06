#!/usr/bin/env bash
# test_screenshot.sh — contract tests for ~/.local/bin/screenshot.
#
# The script is product code invoked by niri/mango keybindings, so these
# tests never touch the real Wayland session, clipboard or config: every
# external tool is a mock installed under its real name in a throwaway
# sandbox, and PATH points at that sandbox only.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

SCRIPT="$REPO_ROOT/home/chezmoi/dot_local/bin/executable_screenshot"

SB=""
BIN=""
RC=0
STDOUT=""
STDERR=""
CALLS=""

cleanup_sandbox() {
    if [[ -n "$SB" && -d "$SB" ]]; then
        rm -rf -- "$SB"
    fi
    SB=""
    BIN=""
}

new_sandbox() {
    cleanup_sandbox
    # Fresh mktemp must not land in a sandbox we are about to delete.
    TMPDIR=/tmp
    SB="$(mktemp -d /tmp/aw-screenshot-test-XXXXXX)"
    BIN="$SB/bin"
    mkdir -p "$BIN" "$SB/home" "$SB/tmp" "$SB/state"
    export HOME="$SB/home"
    export TMPDIR="$SB/tmp"
    export MOCK_LOG="$SB/state/calls.log"
    export MOCK_PICTURES="$SB/home/Pictures"
    export MOCK_CLIP_FILE="$SB/state/clipboard.bin"
    mkdir -p "$MOCK_PICTURES/Screenshots"
    : > "$MOCK_LOG"
    : > "$MOCK_CLIP_FILE"

    # Only the real tools the script legitimately needs are symlinked in.
    # Everything that could reach the real session (slurp/grim/swappy/
    # wl-copy/notify-send/xdg-user-dir) is mocked below, and PATH will be
    # this directory only, so nothing can leak out of the sandbox.
    local tool
    for tool in bash cat date dirname head mkdir mktemp od rm tr; do
        ln -s "$(command -v "$tool")" "$BIN/$tool"
    done

    cat > "$BIN/xdg-user-dir" <<'MOCK'
#!/usr/bin/env bash
printf 'xdg-user-dir %s\n' "$*" >> "$MOCK_LOG"
printf '%s\n' "$MOCK_PICTURES"
MOCK

    cat > "$BIN/slurp" <<'MOCK'
#!/usr/bin/env bash
printf 'slurp %s\n' "$*" >> "$MOCK_LOG"
printf '%s\n' "${MOCK_SLURP_OUT:-}"
exit "${MOCK_SLURP_RC:-0}"
MOCK

    cat > "$BIN/grim" <<'MOCK'
#!/usr/bin/env bash
printf 'grim %s\n' "$*" >> "$MOCK_LOG"
out="${!#}"
if [[ "${MOCK_GRIM_WRITE:-1}" == 1 ]]; then
    printf '\x89PNG\r\n\x1a\n' > "$out"
    printf 'mock-png-payload\n' >> "$out"
fi
if [[ "${MOCK_GRIM_EMPTY:-0}" == 1 ]]; then
    : > "$out"
fi
exit "${MOCK_GRIM_RC:-0}"
MOCK

    cat > "$BIN/swappy" <<'MOCK'
#!/usr/bin/env bash
printf 'swappy %s\n' "$*" >> "$MOCK_LOG"
infile=""
outfile=""
while (( $# )); do
    case "$1" in
        -f) infile="${2:-}"; shift 2 ;;
        -o) outfile="${2:-}"; shift 2 ;;
        *) shift ;;
    esac
done
if [[ "${MOCK_SWAPPY_WRITE:-1}" == 1 && -n "$infile" && -n "$outfile" ]]; then
    cat -- "$infile" > "$outfile"
fi
exit "${MOCK_SWAPPY_RC:-0}"
MOCK

    cat > "$BIN/wl-copy" <<'MOCK'
#!/usr/bin/env bash
printf 'wl-copy\n' >> "$MOCK_LOG"
cat > "$MOCK_CLIP_FILE"
exit "${MOCK_WLCOPY_RC:-0}"
MOCK

    cat > "$BIN/notify-send" <<'MOCK'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >> "$MOCK_LOG"
exit 0
MOCK

    find "$BIN" -maxdepth 1 -type f -exec chmod +x {} +

    export MOCK_SLURP_RC=0
    export MOCK_SLURP_OUT='10,10 200x100'
    export MOCK_GRIM_RC=0
    export MOCK_GRIM_WRITE=1
    export MOCK_GRIM_EMPTY=0
    export MOCK_SWAPPY_RC=0
    export MOCK_SWAPPY_WRITE=1
    export MOCK_WLCOPY_RC=0
}

run_screenshot() {
    : > "$MOCK_LOG"
    : > "$MOCK_CLIP_FILE"
    PATH="$BIN" "$SCRIPT" >"$SB/state/stdout" 2>"$SB/state/stderr"
    RC=$?
    STDOUT="$(cat "$SB/state/stdout")"
    STDERR="$(cat "$SB/state/stderr")"
    CALLS="$(cat "$MOCK_LOG")"
}

capture_file() { # first (and normally only) PNG under Pictures/Screenshots
    find "$MOCK_PICTURES/Screenshots" -maxdepth 1 -type f -name '*.png' -print -quit 2>/dev/null
}

temp_leftovers() {
    find "$TMPDIR" -type f -print 2>/dev/null
}

assert_rc_is() { # assert_rc_is <want> <desc>
    if [[ "$RC" == "$1" ]]; then
        t_ok
    else
        t_fail "$2: expected rc=$1, got rc=$RC (stderr: $STDERR)"
    fi
}

assert_rc_not() { # assert_rc_not <unwanted> <desc>
    if [[ "$RC" != "$1" ]]; then
        t_ok
    else
        t_fail "$2: expected rc != $1 (stderr: $STDERR)"
    fi
}

# ---------------------------------------------------------------------------
t_title "screenshot script: static contract"

t_case "bash -n parses the script"
bash -n "$SCRIPT" >/dev/null 2>&1
assert_rc 0 "bash -n"

t_case "script has the expected bash shebang"
assert_eq "shebang" '#!/usr/bin/env bash' "$(head -n 1 "$SCRIPT")"

t_case "script keeps its executable bit"
if [[ -x "$SCRIPT" ]]; then t_ok; else t_fail "$SCRIPT is not executable"; fi

t_case "script never passes --early-exit to swappy"
assert_not_contains "script body" "--early-exit" "$SCRIPT"

t_case "script does not swallow grim/swappy failures with || true"
if grep -Eq '(grim|swappy).*\|\|[[:space:]]*true' "$SCRIPT"; then
    t_fail "found '|| true' hiding a grim/swappy failure in $SCRIPT"
else
    t_ok
fi

# ---------------------------------------------------------------------------
t_title "screenshot: success path"

new_sandbox
run_screenshot

t_case "exits 0"
assert_rc_is 0 "success"

t_case "writes no error output"
assert_eq "stderr" "" "$STDERR"

captured="$(capture_file)"
t_case "saves a PNG under <PICTURES>/Screenshots with the expected name"
if [[ "$captured" == *"/Screenshots/Screenshot from "* ]]; then
    t_ok
else
    t_fail "unexpected output path: [$captured]"
fi

t_case "saved PNG is non-empty"
if [[ -s "$captured" ]]; then t_ok; else t_fail "missing or empty PNG at $captured"; fi

t_case "clipboard received exactly the saved PNG bytes"
if [[ -n "$captured" ]] && cmp -s -- "$captured" "$MOCK_CLIP_FILE"; then
    t_ok
else
    t_fail "clipboard content differs from $captured"
fi

t_case "swappy was called with -f and -o and without --early-exit"
if [[ "$CALLS" == *"swappy -f "* && "$CALLS" == *" -o "* && "$CALLS" != *"--early-exit"* ]]; then
    t_ok
else
    t_fail "unexpected swappy call: $CALLS"
fi

t_case "grim wrote the temporary file, not stdout"
if [[ "$CALLS" == *"grim -t png -g "* && "$CALLS" != *"grim -t png -g  -"* ]]; then
    t_ok
else
    t_fail "unexpected grim call: $CALLS"
fi

t_case "temporary file is cleaned up by the trap"
assert_eq "leftover temp files" "" "$(temp_leftovers)"

t_case "success path shows no critical notification"
assert_not_contains "calls" "notify-send" "$CALLS"

cleanup_sandbox

# ---------------------------------------------------------------------------
t_title "screenshot: slurp cancellation"

new_sandbox
export MOCK_SLURP_RC=1
export MOCK_SLURP_OUT=''
run_screenshot

t_case "Esc (rc=1, empty output) exits 0"
assert_rc_is 0 "slurp cancel rc=1"

t_case "Esc is silent on stderr"
assert_eq "stderr" "" "$STDERR"

t_case "Esc does not call grim, swappy, wl-copy or notify-send"
if [[ "$CALLS" != *"grim "* && "$CALLS" != *"swappy "* && "$CALLS" != *"wl-copy"* && "$CALLS" != *"notify-send"* ]]; then
    t_ok
else
    t_fail "unexpected calls after slurp cancel: $CALLS"
fi

t_case "Esc writes no output file"
assert_eq "output png" "" "$(capture_file)"

cleanup_sandbox

# ---------------------------------------------------------------------------
t_title "screenshot: slurp returns empty geometry with rc=0"

new_sandbox
export MOCK_SLURP_RC=0
export MOCK_SLURP_OUT=''
run_screenshot

t_case "empty geometry exits 0"
assert_rc_is 0 "slurp empty output"

t_case "empty geometry does not call grim, swappy or wl-copy"
if [[ "$CALLS" != *"grim "* && "$CALLS" != *"swappy "* && "$CALLS" != *"wl-copy"* ]]; then
    t_ok
else
    t_fail "unexpected calls after empty slurp output: $CALLS"
fi

t_case "empty geometry writes no output file"
assert_eq "output png" "" "$(capture_file)"

cleanup_sandbox

# ---------------------------------------------------------------------------
t_title "screenshot: grim failure"

new_sandbox
export MOCK_GRIM_RC=1
export MOCK_GRIM_WRITE=0
run_screenshot

t_case "grim failure returns non-zero"
assert_rc_not 0 "grim failure"

t_case "grim failure explains itself on stderr"
assert_contains "stderr" "grim" "$STDERR"

t_case "grim failure triggers a critical notification"
assert_contains "calls" "notify-send --urgency=critical" "$CALLS"

t_case "grim failure leaves the clipboard untouched"
assert_not_contains "calls" "wl-copy" "$CALLS"

t_case "grim failure writes no output file"
assert_eq "output png" "" "$(capture_file)"

t_case "grim failure still cleans up the temporary file"
assert_eq "leftover temp files" "" "$(temp_leftovers)"

cleanup_sandbox

# ---------------------------------------------------------------------------
t_title "screenshot: grim writes an empty file"

new_sandbox
export MOCK_GRIM_EMPTY=1
run_screenshot

t_case "empty capture returns non-zero"
assert_rc_not 0 "grim empty capture"

t_case "empty capture explains itself on stderr"
assert_contains "stderr" "PNG" "$STDERR"

t_case "empty capture leaves the clipboard untouched"
assert_not_contains "calls" "wl-copy" "$CALLS"

t_case "empty capture writes no output file"
assert_eq "output png" "" "$(capture_file)"

cleanup_sandbox

# ---------------------------------------------------------------------------
t_title "screenshot: swappy failure"

new_sandbox
export MOCK_SWAPPY_RC=1
export MOCK_SWAPPY_WRITE=0
run_screenshot

t_case "swappy failure returns non-zero"
assert_rc_not 0 "swappy failure"

t_case "swappy failure explains itself on stderr"
assert_contains "stderr" "swappy" "$STDERR"

t_case "swappy failure triggers a critical notification"
assert_contains "calls" "notify-send --urgency=critical" "$CALLS"

t_case "swappy failure leaves the clipboard untouched"
assert_not_contains "calls" "wl-copy" "$CALLS"

t_case "swappy failure writes no output file"
assert_eq "output png" "" "$(capture_file)"

cleanup_sandbox

# ---------------------------------------------------------------------------
t_title "screenshot: swappy exits without writing the output (cancel)"

new_sandbox
export MOCK_SWAPPY_WRITE=0
run_screenshot

t_case "annotation cancel exits 0"
assert_rc_is 0 "swappy cancel"

t_case "annotation cancel is silent on stderr"
assert_eq "stderr" "" "$STDERR"

t_case "annotation cancel leaves the clipboard untouched"
assert_not_contains "calls" "wl-copy" "$CALLS"

t_case "annotation cancel shows no critical notification"
assert_not_contains "calls" "notify-send" "$CALLS"

t_case "annotation cancel writes no output file"
assert_eq "output png" "" "$(capture_file)"

cleanup_sandbox

# ---------------------------------------------------------------------------
t_title "screenshot: wl-copy failure is non-fatal"

new_sandbox
export MOCK_WLCOPY_RC=1
run_screenshot

t_case "wl-copy failure still exits 0"
assert_rc_is 0 "wl-copy failure"

captured="$(capture_file)"
t_case "saved PNG survives a failed clipboard copy"
if [[ -s "$captured" ]]; then t_ok; else t_fail "missing or empty PNG at $captured"; fi

t_case "wl-copy failure warns on stderr"
assert_contains "stderr" "wl-copy" "$STDERR"

t_case "wl-copy failure does not raise a critical notification"
assert_not_contains "calls" "notify-send" "$CALLS"

cleanup_sandbox

# ---------------------------------------------------------------------------
t_title "screenshot: notify-send is optional"

new_sandbox
rm -f "$BIN/notify-send"
run_screenshot

t_case "success path works without notify-send installed"
assert_rc_is 0 "no notify-send"

captured="$(capture_file)"
t_case "no notify-send: PNG and clipboard still match"
if [[ -n "$captured" ]] && cmp -s -- "$captured" "$MOCK_CLIP_FILE"; then
    t_ok
else
    t_fail "clipboard content differs from $captured"
fi

t_case "no notify-send: script is silent on success"
assert_eq "stderr" "" "$STDERR"

cleanup_sandbox

new_sandbox
rm -f "$BIN/notify-send"
export MOCK_GRIM_RC=1
export MOCK_GRIM_WRITE=0
run_screenshot

t_case "grim failure without notify-send still fails loudly on stderr"
assert_rc_not 0 "grim failure, no notify-send"

t_case "grim failure without notify-send still names grim on stderr"
assert_contains "stderr" "grim" "$STDERR"

cleanup_sandbox

# ---------------------------------------------------------------------------
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf '\nscreenshot suite passed (%d cases)\n' "$TESTS_RUN" >&2
    exit 0
else
    printf '\nscreenshot suite failed: %d/%d cases\n' "$TESTS_FAILED" "$TESTS_RUN" >&2
    exit 1
fi

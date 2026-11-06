#!/usr/bin/env bash
# test_screenshot_wiring.sh — static regression net for the screenshot chain.
#
# The chain that has to line up for Print to produce an annotated screenshot:
#
#   image packages (build_files/build.sh: grim + slurp + swappy + wl-clipboard
#   + libnotify) → chezmoi ~/.local/bin/screenshot → niri `Print { spawn
#   "screenshot"; }` (and mango `bind=NONE,Print,spawn,screenshot`) → PATH
#   (~/.bashrc + environment.d/60-atomic-workstation.conf both add
#   ~/.local/bin) → ~/.config/swappy/config.
#
# Two real regressions motivate this file:
#   * scripts/doctor.sh listed grim/slurp/wl-copy but not swappy/screenshot, so
#     a broken annotation stack was invisible to the health check;
#   * the niri keybinding comment still documented "screenshot annotation via
#     satty" even though the image ships swappy, and that confusion is exactly
#     what produced a `screenshot --early-exit` call — not a swappy CLI flag
#     (early_exit is a key in ~/.config/swappy/config).
#
# Almost everything here is a grep/static assertion; the one exception is the
# tests/run.sh TMPDIR regression at the end, which shells out to the runner
# inside a throwaway sandbox. No GUI, no real user config is read or written,
# and no host-specific state is required.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

DOCTOR="${REPO_ROOT}/scripts/doctor.sh"
KEYBINDINGS="${REPO_ROOT}/home/chezmoi/dot_config/niri/keybindings.kdl"
NIRI_CONFIG="${REPO_ROOT}/home/chezmoi/dot_config/niri/config.kdl"
BUILD_SH="${REPO_ROOT}/build_files/build.sh"
MANGO_BINDS="${REPO_ROOT}/home/chezmoi/dot_config/mango/binds.conf"
BASHRC="${REPO_ROOT}/home/chezmoi/dot_bashrc"
ENV_D="${REPO_ROOT}/home/chezmoi/dot_config/environment.d/60-atomic-workstation.conf"
RUN_SH="${REPO_ROOT}/tests/run.sh"

# word_in_line <word> <text> — true when <word> appears as a whole word (so
# `screenshot` does not match `screenshot-window`, and `swappy` does not match
# `swappy-extra`).
word_in_line() {
    local word="$1" text="$2"
    grep -qE "(^|[[:space:]\"'(,])${word}([[:space:]\"'),;]|$)" <<<"$text"
}

# ── doctor.sh ──────────────────────────────────────────────────────
t_title "doctor.sh session layer"

t_case "doctor.sh exists and is syntactically valid"
assert_file_exists "scripts/doctor.sh" "$DOCTOR"
if bash -n "$DOCTOR" 2>/dev/null; then t_ok; else t_fail "bash -n scripts/doctor.sh failed"; fi

t_case "doctor.sh keeps strict mode, FAILS accounting and the sudo/aw_user indirection"
assert_contains "strict mode" 'set -euo pipefail' "$DOCTOR"
assert_contains "aw_user helper" 'aw_user() {' "$DOCTOR"
assert_contains "FAILS counter" 'FAILS=$((FAILS + 1))' "$DOCTOR"
assert_contains "Sudo user resolution" 'SUDO_USER' "$DOCTOR"

# The session-layer binary loop is what turns a missing tool into a visible
# [WARN]. Pull the loop header out so the assertions cannot be satisfied by an
# unrelated mention of the binary elsewhere in the script.
SESSION_LOOP="$(grep -E '^[[:space:]]*for binary in ' "$DOCTOR" | head -1)"
t_case "session layer binary loop is present"
if [[ -n "$SESSION_LOOP" ]]; then t_ok; else t_fail "no 'for binary in ...' loop found in scripts/doctor.sh"; fi

t_case "session layer loop checks grim, slurp and wl-copy (unchanged)"
for binary in grim slurp wl-copy; do
    if word_in_line "$binary" "$SESSION_LOOP"; then t_ok; else t_fail "session-layer loop does not check [$binary]: ${SESSION_LOOP}"; fi
done

t_case "session layer loop checks swappy"
if word_in_line swappy "$SESSION_LOOP"; then t_ok; else t_fail "session-layer loop does not check [swappy]: ${SESSION_LOOP}"; fi

t_case "session layer loop checks screenshot"
if word_in_line screenshot "$SESSION_LOOP"; then t_ok; else t_fail "session-layer loop does not check [screenshot]: ${SESSION_LOOP}"; fi

t_case "session layer loop keeps the aw_have/aw_warn style"
assert_contains "aw_have in loop body" 'if aw_have "$binary"; then aw_ok "$binary"' "$DOCTOR"
assert_contains "aw_warn in loop body" 'aw_warn "$binary not in PATH' "$DOCTOR"

# ── niri keybindings ───────────────────────────────────────────────
t_title "niri screenshot keybindings"

t_case "Print spawns the screenshot wrapper"
assert_contains "Print binds" 'Print { spawn "screenshot"; }' "$KEYBINDINGS"

t_case "Ctrl+Print uses niri's built-in screen action"
assert_contains "Ctrl+Print binds" 'Ctrl+Print { screenshot-screen; }' "$KEYBINDINGS"

t_case "Alt+Print uses niri's built-in window action"
assert_contains "Alt+Print binds" 'Alt+Print { screenshot-window; }' "$KEYBINDINGS"

t_case "the screenshot comment no longer mentions satty"
assert_not_contains "satty is not mentioned at all" 'satty' "$KEYBINDINGS"

# Only the comment lines that document screenshots are inspected, so prose
# elsewhere in the file cannot satisfy (or break) these checks.
SCREENSHOT_COMMENT="$(grep -iE '^[[:space:]]*//' "$KEYBINDINGS" | grep -iE 'screenshot|swappy|grim|slurp')"
t_case "the screenshot comment exists"
if [[ -n "$SCREENSHOT_COMMENT" ]]; then t_ok; else t_fail "no screenshot comment found in keybindings.kdl"; fi

t_case "the screenshot comment documents swappy"
if grep -qiF -- 'swappy' <<<"$SCREENSHOT_COMMENT"; then t_ok; else t_fail "screenshot comment does not mention swappy"; fi

t_case "the screenshot comment documents the grim + slurp capture chain"
for tool in grim slurp; do
    if grep -qiF -- "$tool" <<<"$SCREENSHOT_COMMENT"; then t_ok; else t_fail "screenshot comment does not mention [$tool]"; fi
done

t_case "the screenshot comment mentions --early-exit"
if grep -qF -- '--early-exit' <<<"$SCREENSHOT_COMMENT"; then t_ok; else t_fail "screenshot comment does not mention --early-exit"; fi

t_case "the screenshot comment mentions the early_exit config key"
if grep -qF -- 'early_exit' <<<"$SCREENSHOT_COMMENT"; then t_ok; else t_fail "screenshot comment does not mention the early_exit config key"; fi

t_case "the screenshot comment states --early-exit is not a swappy CLI option"
# Look for a line that names the flag and denies it being a CLI flag/option.
if grep -iF -- '--early-exit' <<<"$SCREENSHOT_COMMENT" \
    | grep -qiE '(not|isn.t)[^.]*(cli|flag|option)'; then
    t_ok
else
    t_fail "screenshot comment does not state that --early-exit is not a swappy CLI option"
fi

t_case "the screenshot comment ties early_exit to ~/.config/swappy/config"
if grep -iF -- 'early_exit' <<<"$SCREENSHOT_COMMENT" | grep -qiE 'config'; then
    t_ok
else
    t_fail "screenshot comment does not tie early_exit to the swappy config file"
fi

# ── image packages ─────────────────────────────────────────────────
t_title "image packages"

t_case "build_files/build.sh exists"
assert_file_exists "build_files/build.sh" "$BUILD_SH"

# Collect the dnf package list (the block that follows `dnf5 ... install \`)
# so a package named in a comment cannot satisfy the assertions below.
BUILD_PKGS="$(awk '
    /dnf[0-9]* .*install/ { inblock = 1; next }
    inblock && /^[[:space:]]*$/ { inblock = 0 }
    inblock { gsub(/\\/, " "); print }
' "$BUILD_SH")"
t_case "build.sh has a dnf install package list"
if [[ -n "$BUILD_PKGS" ]]; then t_ok; else t_fail "could not locate the dnf install list in build_files/build.sh"; fi

t_case "build.sh installs grim + slurp + swappy (annotation chain)"
for pkg in grim slurp swappy; do
    if word_in_line "$pkg" "$BUILD_PKGS"; then t_ok; else t_fail "build_files/build.sh dnf list is missing [$pkg]"; fi
done

t_case "build.sh installs wl-clipboard (swappy's clipboard path)"
if word_in_line wl-clipboard "$BUILD_PKGS"; then t_ok; else t_fail "build_files/build.sh dnf list is missing [wl-clipboard]"; fi

t_case "build.sh installs libnotify (screenshot error notifications)"
if word_in_line libnotify "$BUILD_PKGS"; then t_ok; else t_fail "build_files/build.sh dnf list is missing [libnotify]"; fi

# ── mango ──────────────────────────────────────────────────────────
t_title "mango screenshot bind"

t_case "mango binds Print to the screenshot wrapper"
assert_file_exists "mango/binds.conf" "$MANGO_BINDS"
assert_contains "mango Print bind" 'bind=NONE,Print,spawn,screenshot' "$MANGO_BINDS"

# ── PATH + save location ───────────────────────────────────────────
t_title "PATH and screenshot save path"

t_case "dot_bashrc puts ~/.local/bin on PATH"
assert_file_exists "dot_bashrc" "$BASHRC"
assert_contains "bashrc local bin" '${HOME}/.local/bin' "$BASHRC"

t_case "environment.d puts ~/.local/bin on PATH"
assert_file_exists "environment.d/60-atomic-workstation.conf" "$ENV_D"
assert_contains "environment.d local bin" '${HOME}/.local/bin' "$ENV_D"

t_case "niri saves screenshots under ~/Pictures/Screenshots"
assert_file_exists "niri/config.kdl" "$NIRI_CONFIG"
# Ignore the commented-out `// screenshot-path null` example.
if grep -E '^[[:space:]]*screenshot-path ' "$NIRI_CONFIG" | grep -qF 'Pictures/Screenshots'; then
    t_ok
else
    t_fail "niri config.kdl has no active screenshot-path pointing at Pictures/Screenshots"
fi

# ── test runner TMPDIR fallback ────────────────────────────────────
# layerfs `exec` points TMPDIR at <workspace>/.tmp, a scratch dir that is
# never captured by checkpoint/publish, so in a clean workspace it does not
# exist at all and every suite's bare `mktemp` dies with
# "failed to create file via template ... No such file or directory".
# tests/run.sh therefore has to fall back to /tmp (always present and
# writable on Linux) while leaving an explicitly set, working TMPDIR alone.
# The dynamic cases below prove that end to end by running the real runner on
# the (cheap, config-only) dotfiles suite; sandbox dirs live under /tmp so the
# broken TMPDIR they simulate can never affect the test itself.
t_title "test runner TMPDIR fallback"

TMPDIR_SANDBOX="$(mktemp -d /tmp/aw-tmpdir-XXXXXX 2>/dev/null)"
if [[ -n "$TMPDIR_SANDBOX" ]]; then
    trap 'rm -rf "${TMPDIR_SANDBOX:-/nonexistent-aw-tmpdir}"' EXIT
fi
# Summary line every suite prints, e.g. `dotfiles: 7 checks, 0 failed`.
SUITE_SUMMARY_RE='^[a-z_]+: [0-9]+ checks, [0-9]+ failed$'

# Static shape: a guarded (`-d` / `-w`) fallback, never an unconditional one.
TMPDIR_BLOCK="$(grep -nE 'TMPDIR' "$RUN_SH" 2>/dev/null)"
t_case "tests/run.sh falls back to /tmp when TMPDIR is missing or unwritable"
assert_contains "run.sh reads TMPDIR with a default" 'TMPDIR:-/tmp' "$RUN_SH"
assert_contains "run.sh checks the dir exists" '-d' "$TMPDIR_BLOCK"
assert_contains "run.sh checks the dir is writable" '-w' "$TMPDIR_BLOCK"
assert_contains "run.sh exports the /tmp fallback" 'export TMPDIR=/tmp' "$RUN_SH"
# A top-level `export TMPDIR=/tmp` (no indentation) would clobber a valid
# user TMPDIR; the export must live inside the conditional.
if grep -qE '^export TMPDIR=/tmp' "$RUN_SH"; then
    t_fail "tests/run.sh overrides TMPDIR unconditionally"
else
    t_ok
fi

# bash -n: the new guard must not break parsing of the runner.
t_case "tests/run.sh still parses"
if bash -n "$RUN_SH" 2>/dev/null; then t_ok; else t_fail "bash -n tests/run.sh failed"; fi

# With a broken TMPDIR, dotfiles' bare `mktemp` used to fail the suite.
BAD_TMPDIR="${TMPDIR_SANDBOX}/no-such-dir"
if [[ -n "$BAD_TMPDIR" && -d "$BAD_TMPDIR" ]]; then rmdir "$BAD_TMPDIR" 2>/dev/null; fi
t_case "TMPDIR pointing at a missing dir still runs a suite green"
if [[ -z "$TMPDIR_SANDBOX" ]]; then
    t_fail "could not create a sandbox with mktemp -d /tmp/..."
elif [[ -d "$BAD_TMPDIR" ]]; then
    t_fail "sandbox dir ${BAD_TMPDIR} unexpectedly exists"
else
    bad_out="$(TMPDIR="$BAD_TMPDIR" bash "$RUN_SH" dotfiles 2>&1)"
    bad_rc=$?
    assert_eq "TMPDIR=<missing> run.sh dotfiles exit code" 0 "$bad_rc"
    if grep -qE '^dotfiles: [0-9]+ checks, 0 failed$' <<<"$bad_out"; then
        t_ok
    else
        t_fail "dotfiles suite did not report 0 failed with TMPDIR=${BAD_TMPDIR}: $(tail -3 <<<"$bad_out" | tr '\n' ' ')"
    fi
fi

# A working, explicitly chosen TMPDIR must be left untouched. `bash -x` shows
# whether the guard actually fired, without needing a probe suite in tests/.
GOOD_TMPDIR="${TMPDIR_SANDBOX}/usable"
t_case "an explicitly set, working TMPDIR is not overridden"
if [[ -z "$TMPDIR_SANDBOX" ]]; then
    t_fail "could not create a sandbox with mktemp -d /tmp/..."
else
    mkdir -p "$GOOD_TMPDIR"
    good_trace="$(TMPDIR="$GOOD_TMPDIR" bash -x "$RUN_SH" dotfiles 2>&1)"
    good_rc=$?
    bad_trace="$(TMPDIR="$BAD_TMPDIR" bash -x "$RUN_SH" dotfiles 2>&1)"
    assert_eq "TMPDIR=<usable> run.sh dotfiles exit code" 0 "$good_rc"
    if grep -qF 'export TMPDIR=/tmp' <<<"$good_trace"; then
        t_fail "run.sh replaced a usable TMPDIR (${GOOD_TMPDIR}) with /tmp"
    else
        t_ok
    fi
    # Sanity: the same trace hook DOES see the fallback when TMPDIR is broken,
    # so the check above cannot pass vacuously.
    if grep -qF 'export TMPDIR=/tmp' <<<"$bad_trace"; then t_ok; else t_fail "run.sh never applied the /tmp fallback"; fi
fi

# Normal TMPDIR: one suite, one summary line.
t_case "run.sh dotfiles under a normal TMPDIR runs exactly one suite"
normal_out="$(bash "$RUN_SH" dotfiles 2>&1)"
normal_rc=$?
assert_eq "run.sh dotfiles exit code" 0 "$normal_rc"
summary_lines="$(grep -cE "$SUITE_SUMMARY_RE" <<<"$normal_out")"
assert_eq "suite summary lines" 1 "$summary_lines"
if grep -qE '^dotfiles: [0-9]+ checks, 0 failed$' <<<"$normal_out"; then
    t_ok
else
    t_fail "single-suite run did not report dotfiles clean: $(tail -3 <<<"$normal_out" | tr '\n' ' ')"
fi

# Housekeeping: nothing may be left behind in /tmp.
t_case "TMPDIR sandbox is cleaned up"
if [[ -n "$TMPDIR_SANDBOX" ]]; then rm -rf "$TMPDIR_SANDBOX"; fi
if [[ -z "$TMPDIR_SANDBOX" ]]; then
    t_fail "no sandbox was created"
elif [[ -e "$TMPDIR_SANDBOX" ]]; then
    t_fail "sandbox ${TMPDIR_SANDBOX} was not removed"
else
    t_ok
fi

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "screenshot_wiring: ${TESTS_RUN} checks, 0 failed" >&2
    exit 0
else
    echo "screenshot_wiring: ${TESTS_RUN} checks, ${TESTS_FAILED} failed" >&2
    exit 1
fi

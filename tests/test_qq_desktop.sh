#!/usr/bin/env bash
# test_qq_desktop.sh — the QQ overlay pieces that make the menu entry work:
#   * system_files/usr/bin/linuxqq          — PATH entry point the wayland fix
#     resolves first (`command -v linuxqq`), plain exec into /opt/QQ/qq
#   * system_files/usr/share/applications/qq.desktop — the single, visible menu
#     entry, which is where the IME flags from the Flatpak wrapper must live
#     (the fix only adds --ozone-platform=wayland and forwards extra argv)
#   * system_files/usr/lib/tmpfiles.d/70-qq.conf — boot-time symlink that makes
#     /opt/QQ exist, because /opt -> /var/opt and the build never writes /var
# Every assertion here guards a wiring detail: drop one and QQ either does not
# start, is invisible in the menu, or regresses fcitx5 input.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

LAUNCHER="${REPO_ROOT}/system_files/usr/bin/linuxqq"
DESKTOP="${REPO_ROOT}/system_files/usr/share/applications/qq.desktop"
TMPFILES="${REPO_ROOT}/system_files/usr/lib/tmpfiles.d/70-qq.conf"

# ── /usr/bin/linuxqq ────────────────────────────────────────────────────────
t_title "QQ launcher shim (system_files/usr/bin/linuxqq)"

t_case "launcher exists"
assert_file_exists "launcher" "$LAUNCHER"

t_case "launcher is executable (git mode 0755)"
if [[ -x "$LAUNCHER" ]]; then
    t_ok
else
    t_fail "$LAUNCHER is not executable — the fix's \`command -v linuxqq\` would fail"
fi

t_case "launcher is a POSIX sh script"
first_line="$(head -n 1 "$LAUNCHER" 2>/dev/null || true)"
assert_eq "shebang" "#!/bin/sh" "$first_line"

t_case "launcher execs /opt/QQ/qq and forwards \"\$@\""
assert_contains "exec line" 'exec /opt/QQ/qq "$@"' "$LAUNCHER"
# ...and it must be the execing form, not a forking run with an ignored rc.
assert_contains "uses exec" 'exec ' "$LAUNCHER"

t_case "launcher never calls linuxqq-wayland-fix (would recurse)"
assert_not_contains "no fix recursion" "linuxqq-wayland-fix" "$LAUNCHER"

t_case "launcher parses as a valid sh script"
if sh -n "$LAUNCHER" 2>/dev/null; then
    t_ok
else
    t_fail "sh -n rejected $LAUNCHER"
fi

t_case "launcher is what the fix finds as \`command -v linuxqq\`"
resolved="$(PATH="${REPO_ROOT}/system_files/usr/bin:${PATH}" command -v linuxqq 2>/dev/null || true)"
assert_eq "resolution order" "$LAUNCHER" "$resolved"

# ── /usr/share/applications/qq.desktop ──────────────────────────────────────
t_title "QQ menu entry (system_files/usr/share/applications/qq.desktop)"

t_case "desktop entry exists"
assert_file_exists "desktop entry" "$DESKTOP"

t_case "desktop entry has exactly one [Desktop Entry] group"
group_count="$(grep -c '^\[Desktop Entry\]$' "$DESKTOP" 2>/dev/null || true)"
assert_eq "single menu entry" "1" "$group_count"

t_case "desktop entry is an Application named QQ"
assert_contains "Type" "Type=Application" "$DESKTOP"
assert_contains "Name" "Name=QQ" "$DESKTOP"

t_case "Exec runs linuxqq-wayland-fix with both Wayland IME flags and %U"
exec_line="$(grep -m 1 '^Exec=' "$DESKTOP" 2>/dev/null || true)"
assert_eq "Exec line" \
    "Exec=linuxqq-wayland-fix --enable-wayland-ime --wayland-text-input-version=3 %U" \
    "$exec_line"
# Broken out so a regression names the flag that went missing.
assert_contains "runs the wayland fix" "linuxqq-wayland-fix" "$exec_line"
assert_contains "wayland IME enabled" "--enable-wayland-ime" "$exec_line"
assert_contains "text-input v3" "--wayland-text-input-version=3" "$exec_line"
assert_contains "forwards URLs/files" "%U" "$exec_line"

t_case "desktop entry carries icon, terminal, category and WM class"
assert_contains "Icon" "Icon=qq" "$DESKTOP"
assert_contains "Terminal" "Terminal=false" "$DESKTOP"
assert_contains "Categories" "Categories=Network;InstantMessaging;" "$DESKTOP"
assert_contains "StartupWMClass" "StartupWMClass=QQ" "$DESKTOP"

t_case "desktop entry stays visible in the menu (no NoDisplay key)"
# Check for the KEY, not the word: a comment may legitimately explain why
# NoDisplay is absent, but a `NoDisplay=` line would hide the entry.
nodisplay_keys="$(grep -E '^[[:space:]]*NoDisplay[[:space:]]*=' "$DESKTOP" 2>/dev/null || true)"
assert_eq "no NoDisplay key" "" "$nodisplay_keys"

t_case "desktop-file-validate accepts qq.desktop"
if command -v desktop-file-validate >/dev/null 2>&1; then
    validate_out="$(desktop-file-validate "$DESKTOP" 2>&1)"
    validate_rc=$?
    if [[ $validate_rc -eq 0 ]]; then
        t_ok
    else
        t_fail "desktop-file-validate rc=$validate_rc: $validate_out"
    fi
else
    printf '(desktop-file-validate not installed — skipped) ' >&2
    t_ok
fi

# ── /usr/lib/tmpfiles.d/70-qq.conf ─────────────────────────────────────────
t_title "QQ boot-time /opt/QQ symlink (system_files/usr/lib/tmpfiles.d/70-qq.conf)"

t_case "tmpfiles drop-in exists"
assert_file_exists "tmpfiles drop-in" "$TMPFILES"

t_case "tmpfiles rule links /var/opt/QQ to /usr/lib/QQ"
assert_contains "rule line" "L+ /var/opt/QQ - - - - /usr/lib/QQ" "$TMPFILES"

t_case "the rule is the only non-comment line in the drop-in"
mapfile -t rules < <(grep -vE '^[[:space:]]*(#|$)' "$TMPFILES" 2>/dev/null || true)
assert_eq "rule count" "1" "${#rules[@]}"
assert_eq "rule text" "L+ /var/opt/QQ - - - - /usr/lib/QQ" "${rules[0]:-}"

t_case "systemd-tmpfiles parses the drop-in and plans the symlink"
if command -v systemd-tmpfiles >/dev/null 2>&1; then
    tmp_root="$(mktemp -d /tmp/aw-qq-tmpfiles-XXXXXX)"
    mkdir -p "${tmp_root}/usr/lib/tmpfiles.d"
    cp "$TMPFILES" "${tmp_root}/usr/lib/tmpfiles.d/70-qq.conf"
    tmpfiles_out="$(systemd-tmpfiles --root="$tmp_root" --create --dry-run 2>&1)"
    tmpfiles_rc=$?
    rm -rf "$tmp_root"
    if [[ $tmpfiles_rc -eq 0 ]] \
        && grep -qF 'var/opt/QQ' <<<"$tmpfiles_out" \
        && grep -qF '/usr/lib/QQ' <<<"$tmpfiles_out"; then
        t_ok
    else
        t_fail "systemd-tmpfiles rc=$tmpfiles_rc: $tmpfiles_out"
    fi
else
    printf '(systemd-tmpfiles not installed — skipped) ' >&2
    t_ok
fi

printf '\nqq_desktop: %d checks, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED" >&2
exit "$TESTS_FAILED"

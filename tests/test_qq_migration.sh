#!/usr/bin/env bash
# test_qq_migration.sh — scripts/migrate-qq-from-flatpak.sh
#
# The Flatpak QQ build keeps its profile in the sandbox:
#   $HOME/.var/app/com.qq.QQ/config/QQ      (1.5 GB on the reference machine)
# The native build reads $XDG_CONFIG_HOME/QQ instead, which is empty on a
# machine that has only ever run the Flatpak. Migrating is therefore a COPY,
# never a move: the Flatpak tree stays the fallback (and the source of truth)
# until the user uninstalls the Flatpak themselves.
#
# Everything here runs against a throwaway HOME from tests/lib.sh (t_setup
# mktemp's the sandbox), so the real ~/.var/app/com.qq.QQ is never touched.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

SCRIPT="$REPO_ROOT/scripts/migrate-qq-from-flatpak.sh"
RECIPE_FILE="$REPO_ROOT/system_files/usr/share/ublue-os/just/60-custom.just"

t_title "QQ profile migration (Flatpak -> native)"

t_setup

# Hard guard: every path below is built from $HOME, so $HOME MUST be the
# disposable sandbox. If this ever trips, the suite would be editing the real
# user profile — fail loudly instead.
if [[ -z "$T_SANDBOX" || "$HOME" != "$T_SANDBOX"/* ]]; then
    printf 'FATAL: HOME (%s) is not inside the throwaway sandbox (%s)\n' \
        "${HOME:-unset}" "${T_SANDBOX:-unset}" >&2
    exit 1
fi

FLATPAK_PROFILE="$HOME/.var/app/com.qq.QQ/config/QQ"
NATIVE_PROFILE="$HOME/.config/QQ"

# ── helpers ───────────────────────────────────────────────────────────────

# tree_sig <dir> — stable fingerprint of a tree: type + path + content hash.
# Symlinks are fingerprinted by their target, not followed.
tree_sig() {
    local dir="$1"
    [[ -d "$dir" ]] || {
        printf 'MISSING\n'
        return 0
    }
    (
        cd "$dir" || exit 1
        find . -mindepth 1 -print | LC_ALL=C sort | while IFS= read -r p; do
            if [[ -L "$p" ]]; then
                printf 'l %s -> %s\n' "$p" "$(readlink "$p")"
            elif [[ -d "$p" ]]; then
                printf 'd %s\n' "$p"
            else
                printf 'f %s %s\n' "$p" "$(md5sum <"$p" | cut -d' ' -f1)"
            fi
        done
    )
}

# make_fake_profile <dir> — a small stand-in for the 1.5 GB Flatpak QQ tree:
# nested account directory, the global/ settings dir, a binary blob and a
# symlink, so a copy that drops one of them is caught.
make_fake_profile() {
    local dir="$1" acct
    acct="nt_qq_bf1d4f49becc2dd305e38b12ff8a4530"
    mkdir -p "$dir/$acct" "$dir/global/settings"
    printf 'message-history\n' >"$dir/$acct/Msg.db"
    printf 'account-config\n' >"$dir/$acct/Profile.info"
    printf 'window-geometry\n' >"$dir/global/settings/ui.ini"
    head -c 4096 /dev/urandom >"$dir/$acct/blob.bin"
    ln -sf "$acct/Msg.db" "$dir/latest.db"
}

# ── 1. static contract ────────────────────────────────────────────────────
t_case "script exists, is executable and passes bash -n"
assert_file_exists "script present" "$SCRIPT"
if [[ -x "$SCRIPT" ]]; then t_ok; else t_fail "script is not executable: $SCRIPT"; fi
if bash -n "$SCRIPT" 2>/dev/null; then t_ok; else t_fail "bash -n rejected $SCRIPT"; fi

# ── 2. --help ─────────────────────────────────────────────────────────────
t_case "--help prints usage and exits 0"
out=$(bash "$SCRIPT" --help 2>&1)
assert_rc 0 "--help exits 0"
assert_contains "usage block" "Usage:" "$out"
assert_contains "documents --dry-run" "--dry-run" "$out"
assert_contains "documents --force" "--force" "$out"
assert_contains "documents --from" "--from" "$out"
assert_contains "documents --to" "--to" "$out"
if [[ -e "$NATIVE_PROFILE" ]]; then t_fail "--help created $NATIVE_PROFILE"; else t_ok; fi

# ── 3. bad usage ──────────────────────────────────────────────────────────
t_case "unknown flag is bad usage: exit 2, usage on stderr, no target"
out=$(bash "$SCRIPT" --nope 2>&1)
assert_rc 2 "unknown flag exits 2"
assert_contains "usage shown" "Usage:" "$out"
if [[ -e "$NATIVE_PROFILE" ]]; then t_fail "bad usage created $NATIVE_PROFILE"; else t_ok; fi

t_case "--from without a value is bad usage: exit 2"
out=$(bash "$SCRIPT" --from 2>&1)
assert_rc 2 "--from with no value exits 2"
assert_contains "usage shown" "Usage:" "$out"

# ── 4. nothing to migrate ─────────────────────────────────────────────────
t_case "missing source directory: nothing to migrate, exit 0"
if [[ -e "$FLATPAK_PROFILE" ]]; then t_fail "sandbox source should be absent: $FLATPAK_PROFILE"; else t_ok; fi
out=$(bash "$SCRIPT" 2>&1)
assert_rc 0 "missing source exits 0"
assert_contains "reports nothing to migrate" "nothing to migrate" "$out"
if [[ -e "$NATIVE_PROFILE" ]]; then t_fail "created $NATIVE_PROFILE with no source"; else t_ok; fi

t_case "empty source directory: nothing to migrate, exit 0"
EMPTY_SRC="$T_SANDBOX/empty-src"
mkdir -p "$EMPTY_SRC"
out=$(bash "$SCRIPT" --from "$EMPTY_SRC" --to "$T_SANDBOX/empty-dst" 2>&1)
assert_rc 0 "empty source exits 0"
assert_contains "reports nothing to migrate" "nothing to migrate" "$out"
if [[ -e "$T_SANDBOX/empty-dst" ]]; then t_fail "created target for an empty source"; else t_ok; fi

# ── 5. --dry-run ──────────────────────────────────────────────────────────
t_case "--dry-run reports source/target/size and creates nothing"
DRY_SRC="$T_SANDBOX/dry/from/QQ"
DRY_DST="$T_SANDBOX/dry/to/QQ"
make_fake_profile "$DRY_SRC"
src_sig_before="$(tree_sig "$DRY_SRC")"
want_size="$(du -sh "$DRY_SRC" | cut -f1)"
out=$(bash "$SCRIPT" --dry-run --from "$DRY_SRC" --to "$DRY_DST" 2>&1)
assert_rc 0 "--dry-run exits 0"
assert_contains "names the source" "$DRY_SRC" "$out"
assert_contains "names the target" "$DRY_DST" "$out"
assert_contains "reports the size (du -sh)" "$want_size" "$out"
assert_contains "marked as a dry run" "dry" "$out"
if [[ -e "$DRY_DST" ]]; then t_fail "--dry-run created $DRY_DST"; else t_ok; fi
assert_eq "source unchanged by --dry-run" "$src_sig_before" "$(tree_sig "$DRY_SRC")"

# ── 6. the real copy ──────────────────────────────────────────────────────
t_case "populated Flatpak profile is copied into \$XDG_CONFIG_HOME/QQ"
make_fake_profile "$FLATPAK_PROFILE"
src_sig_before="$(tree_sig "$FLATPAK_PROFILE")"
want_size="$(du -sh "$FLATPAK_PROFILE" | cut -f1)"
export XDG_CONFIG_HOME="$HOME/.config"
out=$(bash "$SCRIPT" 2>&1)
assert_rc 0 "copy exits 0"
assert_eq "target tree mirrors the source tree" "$src_sig_before" "$(tree_sig "$NATIVE_PROFILE")"
assert_file_exists "nested account dir copied" \
    "$NATIVE_PROFILE/nt_qq_bf1d4f49becc2dd305e38b12ff8a4530/Msg.db"
assert_file_exists "global/ settings copied" "$NATIVE_PROFILE/global/settings/ui.ini"
assert_contains "summary names the target" "$NATIVE_PROFILE" "$out"
assert_contains "summary reports the size" "$want_size" "$out"
assert_contains "summary reports the file count" "files" "$out"

t_case "the Flatpak source is left untouched by the copy"
assert_eq "source tree unchanged" "$src_sig_before" "$(tree_sig "$FLATPAK_PROFILE")"
assert_file_exists "source still exists" "$FLATPAK_PROFILE/nt_qq_bf1d4f49becc2dd305e38b12ff8a4530/Msg.db"

t_case "next steps mention uninstalling the Flatpak and the QR re-login"
assert_contains "flatpak uninstall hint" "flatpak uninstall com.qq.QQ" "$out"
assert_contains "QR re-login hint" "QR" "$out"
if grep -qiF -- "quit QQ" <<<"$out"; then t_ok; else t_fail "quit QQ hint: missing [quit QQ]"; fi

t_case "the script never invokes flatpak"
if [[ -e "${MOCK_STATE:-/nonexistent}/flatpak" ]]; then
    t_fail "flatpak was executed (mock state appeared in $MOCK_STATE)"
else
    t_ok
fi

# ── 7. guarded re-run ─────────────────────────────────────────────────────
t_case "second run without --force refuses: exit 1, target untouched"
dst_sig_before="$(tree_sig "$NATIVE_PROFILE")"
src_sig_before="$(tree_sig "$FLATPAK_PROFILE")"
out=$(bash "$SCRIPT" 2>&1)
assert_rc 1 "non-empty target without --force exits 1"
assert_contains "message names the target" "$NATIVE_PROFILE" "$out"
assert_contains "message names the --force escape hatch" "--force" "$out"
assert_eq "target untouched after refusal" "$dst_sig_before" "$(tree_sig "$NATIVE_PROFILE")"
assert_eq "source untouched after refusal" "$src_sig_before" "$(tree_sig "$FLATPAK_PROFILE")"

# ── 8. --force merge ──────────────────────────────────────────────────────
t_case "--force merges over an existing target and is re-runnable"
printf 'target-only-marker\n' >"$NATIVE_PROFILE/keep-me.txt"
# a stale copy of a source file must be refreshed by the merge
printf 'stale\n' >"$NATIVE_PROFILE/nt_qq_bf1d4f49becc2dd305e38b12ff8a4530/Msg.db"
out=$(bash "$SCRIPT" --force 2>&1)
assert_rc 0 "--force exits 0"
assert_contains "summary names the target" "$NATIVE_PROFILE" "$out"
assert_file_exists "target-only file survives the merge" "$NATIVE_PROFILE/keep-me.txt"
assert_eq "stale target file refreshed from the source" \
    "message-history" "$(cat "$NATIVE_PROFILE/nt_qq_bf1d4f49becc2dd305e38b12ff8a4530/Msg.db")"
assert_eq "source still intact after --force" "$src_sig_before" "$(tree_sig "$FLATPAK_PROFILE")"
assert_file_exists "both trees still present" "$FLATPAK_PROFILE/global/settings/ui.ini"

t_case "--force is idempotent (second --force run still exits 0)"
out=$(bash "$SCRIPT" --force 2>&1)
assert_rc 0 "repeat --force exits 0"

# ── 9. explicit overrides ─────────────────────────────────────────────────
t_case "--from/--to overrides are honoured"
ALT_SRC="$T_SANDBOX/alt/from"
ALT_DST="$T_SANDBOX/alt/to/QQ"
make_fake_profile "$ALT_SRC"
alt_sig="$(tree_sig "$ALT_SRC")"
out=$(bash "$SCRIPT" --from "$ALT_SRC" --to "$ALT_DST" 2>&1)
assert_rc 0 "custom --from/--to exits 0"
assert_eq "custom target mirrors the custom source" "$alt_sig" "$(tree_sig "$ALT_DST")"

t_case "the default target honours \$XDG_CONFIG_HOME"
XDG_SRC="$T_SANDBOX/xdg/from"
export XDG_CONFIG_HOME="$T_SANDBOX/xdg/config"
mkdir -p "$XDG_SRC"
printf 'xdg\n' >"$XDG_SRC/marker.txt"
out=$(bash "$SCRIPT" --from "$XDG_SRC" 2>&1)
assert_rc 0 "XDG_CONFIG_HOME copy exits 0"
assert_file_exists "landed under \$XDG_CONFIG_HOME/QQ" "$XDG_CONFIG_HOME/QQ/marker.txt"

# ── 10. ujust wiring ──────────────────────────────────────────────────────
t_case "ujust recipe atomic-ws-qq-migrate wraps the script"
assert_file_exists "recipe file present" "$RECIPE_FILE"
assert_contains "recipe defined" "atomic-ws-qq-migrate *args:" "$RECIPE_FILE"
assert_contains "recipe in the atomic-workstation group" \
    "[group('atomic-workstation')]" "$RECIPE_FILE"
assert_contains "recipe execs the migration script" \
    'scripts/migrate-qq-from-flatpak.sh' "$RECIPE_FILE"
assert_contains "recipe uses the ATOMIC_WORKSTATION_DIR convention" \
    'ATOMIC_WORKSTATION_DIR' "$RECIPE_FILE"
assert_contains "recipe has the clone hint" \
    'git clone' "$RECIPE_FILE"

t_teardown

printf '\nqq_migration: %d checks, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED" >&2
exit "$TESTS_FAILED"

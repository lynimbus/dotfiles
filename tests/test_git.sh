#!/usr/bin/env bash
# test_git.sh — sync.sh git behaviour tests.
# Uses a THROWAWAY copy of the repo (fresh git init) so the real repo is
# never touched and uncommitted files are included (a git worktree would
# only contain committed files).
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

t_title "git sync behaviour"

make_clone() {
    local d="$1"
    mkdir -p "$d"
    cp -r "$REPO_ROOT/scripts" "$REPO_ROOT/apps" "$REPO_ROOT/containers" "$d/"
    git -C "$d" init -q
    git -C "$d" config user.email test@example.com
    git -C "$d" config user.name "Test"
    git -C "$d" add -A >/dev/null
    git -C "$d" commit -qm "base"
}

t_setup
CLONE="$T_SANDBOX/clone"
make_clone "$CLONE"
export ATOMIC_WS_ROOT="$CLONE"
SYNC="$CLONE/scripts/sync.sh"

# seed one flatpak app so capture produces a change
flatpak remote-add --if-not-exists --user flathub https://example.com/flathub/ >/dev/null 2>&1
flatpak install --user --assumeyes flathub org.git.testapp//stable >/dev/null 2>&1

t_case "sync detects a new inventory change (uncommitted)"
out=$(bash "$SYNC" 2>&1)
assert_contains "change detected" "flatpak/inventory" "$out"
assert_contains "suggests committing" "commit" "$out"

t_case "sync --commit commits ONLY inventory files"
out=$(bash "$SYNC" --commit 2>&1)
assert_contains "commit message" "chore(inventory)" "$(git -C "$CLONE" log -1 --format=%s)"
assert_contains "inventory committed" "committed inventory" "$out"
assert_file_exists "inventory json present" "$CLONE/apps/flatpak/inventory/testbox.json"
if git -C "$CLONE" status --porcelain -- apps/flatpak/inventory | grep -q .; then
    t_fail "inventory still dirty after commit"
else
    t_ok
fi

t_case "sync with no changes reports idempotent state"
out=$(bash "$SYNC" 2>&1)
assert_contains "no change" "up to date" "$out"

t_case "unrelated dirty files are never committed by sync"
echo "scratch" >"$CLONE/UNRELATED.md"
bash "$SYNC" --commit >/dev/null 2>&1
if git -C "$CLONE" status --porcelain | grep -q 'UNRELATED.md'; then
    t_ok
else
    t_fail "UNRELATED.md was committed by sync!"
fi
rm -f "$CLONE/UNRELATED.md"

t_case "push is never attempted without --push (auto-push off)"
# create a change first, so sync reaches the commit/push decision
flatpak install --user --assumeyes flathub org.git.second//stable >/dev/null 2>&1
out=$(bash "$SYNC" --commit 2>&1)
assert_not_contains "no push attempted" "pushed to" "$out"
assert_contains "push skipped" "push skipped" "$out"

t_case "merge/rebase in progress stops sync with instructions"
GD="$(git -C "$CLONE" rev-parse --absolute-git-dir)"
touch "$GD/MERGE_HEAD"
out=$(bash "$SYNC" 2>&1)
rc=$?
rm -f "$GD/MERGE_HEAD"
if [[ $rc -eq 1 ]]; then t_ok; else t_fail "expected rc=1 in merge state, got $rc"; fi
assert_contains "merge state detected" "merge or rebase is in progress" "$out"
assert_contains "manual resolution guidance" "finish it first" "$out"

t_teardown

printf '\ngit sync: %d checks, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED" >&2
exit "$TESTS_FAILED"

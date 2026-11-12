#!/usr/bin/env bash
# Drives the memo commands built from this checkout: record, digest, skip,
# rebuild, search, the 04:00 day boundary, and both failure paths. The digest
# needs the model gateway up, so this is a machine check, not a build-time one.
#
#   just memo-verify
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1

memo=$(nix build --impure --no-link --print-out-paths --expr 'let
  f = builtins.getFlake (toString ./.);
  hm = f.nixosConfigurations.nixos.config.home-manager.users.lynimbus;
in builtins.head (builtins.filter (p: (p.pname or "") == "memo") hm.home.packages)') || exit 1
echo "artifact: $memo"
BIN=$memo/bin

fail=0
check() {
  if [ "$2" = "$3" ]; then
    echo "ok   $1"
  else
    echo "FAIL $1 (want [$3], got [$2])"
    fail=1
  fi
}

MEMO_DIR=$(mktemp -d)
export MEMO_DIR
trap 'rm -rf "$MEMO_DIR"' EXIT

# Three days back, so the fixture is finished no matter what hour this runs at.
day=$(date -d '3 days ago' +%F)
next=$(date -d "$day + 1 day" +%F)
inProgress=$(date -d '-4 hours' +%F)

"$BIN/memo" 我需要一个软件记录零散的想法 >/dev/null
printf '最好有一个ai来帮我整理总结\n' | "$BIN/memo"
check "records reach the inbox" "$(wc -l <"$MEMO_DIR/inbox.md")" 2
check "records are timestamp-prefixed" \
  "$(grep -cE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2} ' "$MEMO_DIR/inbox.md")" 2

# A day runs 04:00 to 03:59: the 22:10 and the 02:00 belong to $day, the 10:00
# to the next one.
{
  printf -- '- %sT22:10 晚上的想法，记零散的一句\n' "$day"
  printf -- '- %sT02:00 凌晨两点的想法\n' "$next"
  printf -- '- %sT10:00 白天的想法\n' "$next"
} >"$MEMO_DIR/inbox.md"

"$BIN/memo-digest" >/dev/null
check "digest exits 0" "$?" 0
check "digest was written for the older day" "$([ -f "$MEMO_DIR/digest/$day.md" ] && echo yes)" yes
check "the same run also covered the day after it" "$([ -f "$MEMO_DIR/digest/$next.md" ] && echo yes)" yes

present() { grep -qF -- "$1" "$2" && echo yes || echo no; }
found() { grep -qF -- "$1" && echo yes || echo no; }
check "a 2am thought belongs to the night before it" "$(present 凌晨两点 "$MEMO_DIR/digest/$day.md")" yes
check "a 10am thought belongs to its own day" "$(present 白天 "$MEMO_DIR/digest/$next.md")" yes
check "a 10am thought is absent from the night before" "$(present 白天 "$MEMO_DIR/digest/$day.md")" no
check "the day still in progress has no digest" "$([ -f "$MEMO_DIR/digest/$inProgress.md" ] && echo yes || echo no)" no

check "the digest opens with a markdown heading" "$(head -1 "$MEMO_DIR/digest/$day.md" | cut -c1)" "#"
check "the digest keeps its input hash out of the document" "$(grep -c source-sha256 "$MEMO_DIR/digest/$day.md")" 0

start=$(date +%s%N)
"$BIN/memo-digest" >/dev/null
check "an unchanged day costs no model call" \
  "$([ $(($(date +%s%N) - start)) -lt 1000000000 ] && echo fast || echo slow)" fast

check "search reaches a raw record" "$("$BIN/memo-read" 零散 | found 'inbox.md:')" yes
check "search reaches a digest" "$("$BIN/memo-read" 凌晨两点 | found 'digest/')" yes

before=$(sha256sum "$MEMO_DIR/digest/$day.md" | cut -d' ' -f1)
MEMO_MODEL=no/such-model "$BIN/memo-digest" --date "$day" --force >/dev/null 2>&1
check "a failed model call exits nonzero" "$?" 1
check "a failed model call leaves the previous digest whole" \
  "$(sha256sum "$MEMO_DIR/digest/$day.md" | cut -d' ' -f1)" "$before"

check "an unknown flag is rejected" "$("$BIN/memo-digest" --nope 2>&1 | grep -c 未知参数)" 1
check "a lone --help prints usage instead of recording" "$("$BIN/memo" --help | grep -c '^memo ')" 1

if [ "$fail" -eq 0 ]; then echo "all checks passed"; else echo "failures above"; fi
exit "$fail"

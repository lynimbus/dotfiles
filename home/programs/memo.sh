#!/usr/bin/env bash
# One script, three names. memo records a thought, memo-digest folds one day of
# records into a theme-grouped page, memo-read opens or searches them. The
# derivation links this file to all three names, so the name it was called as
# picks the job.
#
# The records are the only thing nothing can regenerate, so every branch either
# appends to inbox.md or reads from it. A digest is a cache of what a model said
# about one day: the hash of the records it was built from sits beside it in
# digest/.hash/, and a day whose records changed is rebuilt on the next run, so
# the whole digest directory can be deleted at any time.

data=${MEMO_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/memo}
inbox=$data/inbox.md
digests=$data/digest
promptFile=$data/prompt.md
model=${MEMO_MODEL:-group/deepseek}

usage() {
  cat <<'EOF'
memo <想法>      记一条。不带参数时从标准输入读，或在终端里问一行
memo-digest      把每一天的记录按主题整理成 digest/YYYY-MM-DD.md
  --date <日期>  只处理这一天（YYYY-MM-DD）
  --force        这一天没变也重算
memo-read        打开最新一天的整理稿
  <关键词>       在记录和整理稿里搜索
EOF
}

die() {
  printf '%s: %s\n' "${0##*/}" "$1" >&2
  exit 2
}

isBlank() {
  [ -z "${1//[[:space:]]/}" ]
}

# A record looks like "- 2026-11-13T01:58 thought". The timestamp leads the line
# so rg, sort and a prefix match work without parsing anything.
appendLines() {
  local at=$1 line
  mkdir -p "$data"
  while IFS= read -r line; do
    isBlank "$line" && continue
    printf -- '- %s %s\n' "$at" "$line"
  done >>"$inbox"
}

cmdWrite() {
  local at thought
  at=$(date +%Y-%m-%dT%H:%M)

  # Only a lone flag is help. A thought may well start with a dash, and losing
  # one to a usage page is worse than any convenience this buys.
  if [ "$#" -eq 1 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
    usage
    return 0
  fi

  if [ "$#" -gt 0 ]; then
    appendLines "$at" <<<"$*"
    return 0
  fi

  if [ ! -t 0 ]; then
    appendLines "$at"
    return 0
  fi

  # The keybinding runs this in a floating terminal that closes when the command
  # exits, so one line and Enter is the whole interaction. A longer thought goes
  # in as an argument, where quoting is already free.
  #
  # `read -e` needs a bash with readline (see memo.nix): without it the tty
  # erases one byte per Backspace, which mangles a Chinese character, and
  # Ctrl-H is stored as text. Esc is bound to "clear the line, then Enter",
  # so an accidental summon leaves without writing anything.
  bind 'set editing-mode emacs' 2>/dev/null || true
  bind 'set keyseq-timeout 100' 2>/dev/null || true
  bind '"\e": "\C-a\C-k\C-m"' 2>/dev/null || true

  if [ -s "$inbox" ]; then
    printf '已存 %s 条，最近 3 条：\n' "$(wc -l <"$inbox")"
    tail -n 3 "$inbox" | sed 's/^/  /'
  else
    printf '还没有记录。\n'
  fi
  printf '看全部：bat %s ／ 搜索：memo-read <词> ／ 整理稿：memo-read\n\n' "$inbox"
  read -e -r -p '想法 (Enter 记下 · Esc/空行/Ctrl-C 取消) > ' thought || return 0
  isBlank "$thought" && return 0
  appendLines "$at" <<<"$thought"
  printf '已记录 %s\n' "$thought"
  sleep 0.8
}

# Seeded once and then read from the data directory, so the prompt can be
# rewritten without touching this repository or rebuilding.
seedPrompt() {
  [ -f "$promptFile" ] && return 0
  mkdir -p "$data"
  cat >"$promptFile" <<'EOF'
把这些随手记下的想法整理成一篇日刊。

- 用记录本身的语言写。
- markdown：一个一级标题，按主题分二级标题，每个主题下用要点写。
- 同一个念头出现多次时合并成一条，并注明出现了几次。
- 只输出整理好的 markdown 正文，不要前后解释，不要用代码块包裹。
EOF
}

# A "day" here runs from 04:00 to 03:59, not midnight to midnight. Whoever uses
# this writes around 2am, and a calendar day files those thoughts under a day
# they had already read, so the digest would arrive a full day late. With the
# boundary at 04:00 a 2am thought belongs to the night it was had in, and the
# 05:00 run catches it an hour later.
boundaryHour=4

recordsOf() {
  local day=$1 next
  next=$(date -d "$day + 1 day" +%F)
  # A record is "- 2026-11-12T22:10 ...": the day and its T are one word, which
  # is why the pattern joins them with no space.
  grep -hE "^- (${day}T(0[4-9]|1[0-9]|2[0-3])|${next}T0[0-3]):[0-9]{2} " "$inbox" || true
}

# Each digest's input hash lives beside it rather than inside it, so the digest
# stays a clean document on every surface that reads it.
hashOf() {
  cat "$digests/.hash/$1" 2>/dev/null || true
}

# Both candidate days for every date seen: a date holding only pre-04:00 records
# starts no day of its own, and the day before it is the one that owns them.
daysInInbox() {
  local d
  grep -oE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}' "$inbox" | sed 's/^- //' | sort -u |
    while IFS= read -r d; do
      printf '%s\n' "$d"
      date -d "$d - 1 day" +%F
    done | sort -u || true
}

cmdDigest() {
  local force=0 only="" failed=0 day body sha tmp days
  while [ "$#" -gt 0 ]; do
    case $1 in
    --force) force=1 ;;
    --date)
      only=${2:-}
      [ -n "$only" ] || die "--date 需要一个 YYYY-MM-DD"
      shift
      ;;
    -h | --help)
      usage
      return 0
      ;;
    *) die "未知参数 $1" ;;
    esac
    shift
  done

  if [ ! -f "$inbox" ]; then
    echo "还没有任何记录：$inbox 不存在" >&2
    return 0
  fi
  seedPrompt
  mkdir -p "$digests"

  # Only finished days get a digest: a day still being written would produce a
  # page that is stale before the reader gets to it. Days the machine was off
  # for are caught up on the next run instead of skipped.
  if [ -n "$only" ]; then
    days=$only
  else
    days=$(daysInInbox | awk -v today="$(date -d "-$boundaryHour hours" +%F)" '$0 < today')
  fi

  while IFS= read -r day; do
    isBlank "$day" && continue
    body=$(recordsOf "$day")
    isBlank "$body" && continue
    sha=$(printf '%s\n' "$body" | sha256sum | cut -d' ' -f1)

    # A rerun over an unchanged day costs one sha256sum and no model call.
    if [ "$force" -eq 0 ] && [ -f "$digests/$day.md" ] && [ "$(hashOf "$day")" = "$sha" ]; then
      continue
    fi

    tmp=$(mktemp -d)
    if ! {
      cat "$promptFile" >"$tmp/prompt.md" &&
        printf '\n这一天（04:00 到次日 03:59）的记录：\n\n' >>"$tmp/prompt.md" &&
        printf '%s\n' "$body" >>"$tmp/prompt.md" &&
        pi -p --no-tools --no-session --model "$model" <"$tmp/prompt.md" >"$tmp/out.md" 2>"$tmp/err"
    }; then
      failed=1
      notify-send --app-name=memo "memo：$day 整理失败" "$(head -c 300 "$tmp/err")" || true
      rm -rf "$tmp"
      continue
    fi
    if [ ! -s "$tmp/out.md" ]; then
      failed=1
      notify-send --app-name=memo "memo：$day 整理为空" "模型没有返回内容" || true
      rm -rf "$tmp"
      continue
    fi

    mv -f "$tmp/out.md" "$digests/$day.md"
    mkdir -p "$digests/.hash"
    printf '%s\n' "$sha" >"$digests/.hash/$day"
    rm -rf "$tmp"
    printf '%s\n' "$digests/$day.md"
  done <<<"$days"

  return "$failed"
}

cmdRead() {
  if [ "$#" -gt 0 ]; then
    local targets=()
    [ -f "$inbox" ] && targets+=("$inbox")
    [ -d "$digests" ] && targets+=("$digests")
    [ "${#targets[@]}" -gt 0 ] || die "还没有任何记录"
    exec rg --line-number --no-heading --context=2 -- "$1" "${targets[@]}"
  fi

  local latest=""
  if [ -d "$digests" ]; then
    latest=$(find "$digests" -name '*.md' -type f | sort | tail -n 1)
  fi
  if [ -n "$latest" ]; then
    exec bat --style=plain --paging=auto "$latest"
  fi
  [ -f "$inbox" ] || die "还没有任何记录：$inbox 不存在"
  exec bat --style=plain --paging=auto "$inbox"
}

case ${0##*/} in
memo-digest) cmdDigest "$@" ;;
memo-read) cmdRead "$@" ;;
memo) cmdWrite "$@" ;;
*) die "请以 memo、memo-digest 或 memo-read 之一调用" ;;
esac

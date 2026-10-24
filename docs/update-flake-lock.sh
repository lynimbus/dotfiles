#!/usr/bin/env bash
# 更新 flake.lock，并保证变更始终落在 jj 栈顶的独立提交里。
#
# 规则：
#   - 栈里的 lock 提交位置正确 -> 复用它，直接跑 nix flake update；
#   - 位置不对 -> 把它 rebase 到栈顶；
#   - 还没有 lock 提交 -> 在栈顶新建一个；
#   - 跑完回到原来的工作副本；依赖没变化时丢掉新建的空提交。
set -euo pipefail
cd "$(jj root)"
export NIX_CONFIG="access-tokens = github.com=$(gh auth token)"

lock_msg='chore(flake): 更新 flake.lock'
stack='(ancestors(@) | @ | descendants(@))'

cid() { jj log --no-graph -r "$1" -T 'change_id'; }
is_empty() { [[ -z "$(jj diff --summary -r "$1")" ]]; }
change() { jj log --no-graph -r "$1" -T 'change_id ++ "\t" ++ description.first_line() ++ "\n"'; }
first() { awk -F'\t' 'NR == 1 { print $1 }'; }

orig=$(cid @)
lock=$(change "$stack" | awk -F'\t' -v m="$lock_msg" '$2 == m && !f { print $1; f = 1 }')
# lock 提交应该挂在谁下面：栈里最靠上的「有内容」提交（@ 和 lock 提交本身除外）
if [[ -n "$lock" ]]; then
    anchor=$(change "heads($stack ~ @ ~ empty() ~ $lock)" | first)
else
    anchor=$(change "heads($stack ~ @ ~ empty())" | first)
fi

reuse=0
if [[ -n "$lock" ]]; then
    # anchor 为空表示栈里除了 lock 提交没有别的内容提交，那就无需搬动
    if [[ -z "$anchor" ]] || [[ "$(cid "$lock-")" == "$anchor" ]]; then
        reuse=1
    fi
fi

created=0
if [[ $reuse == 1 ]]; then
    echo "[update] 复用栈顶的 lock 提交"
elif [[ -n "$lock" ]]; then
    echo "[update] 把已有的 lock 提交挪到栈顶"
    jj rebase -r "$lock" -A "$anchor" >/dev/null
else
    echo "[update] 新建 lock 提交到栈顶"
    if [[ -n "$anchor" ]]; then
        jj new -A "$anchor" -m "$lock_msg" >/dev/null
    else
        jj new -m "$lock_msg" >/dev/null
    fi
    created=1
fi

[[ "$(cid @)" == "$lock" ]] || jj edit "$lock" >/dev/null

nix flake update

if is_empty @; then
    echo "[update] 依赖没有变化，放弃空提交"
    [[ $created == 1 ]] && jj abandon @ >/dev/null
fi

if [[ "$(cid @ 2>/dev/null)" != "$orig" ]]; then
    jj edit "$orig" >/dev/null 2>&1 || jj new >/dev/null
fi
echo "[update] 完成"

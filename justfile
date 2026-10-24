default:
    @just --list

switch:
    nh os switch .

build:
    nh os build .

# 更新 flake.lock；变更永远落在 jj 栈顶的独立提交里
update:
    docs/update-flake-lock.sh

check:
    nix flake check --no-build

lint-msg file="":
    #!/usr/bin/env bash
    set -uo pipefail
    if [[ -n "{{file}}" ]]; then
        exec docs/lint-commit-message.sh "{{file}}"
    fi
    fail=0
    while IFS= read -r -d '' msg; do
        printf '%s\n' "$msg" | docs/lint-commit-message.sh - || fail=1
    done < <(jj log --no-graph --ignore-working-copy -r '::main ~ root()' -T 'description ++ "\0"')
    exit "$fail"

lint-hook:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p .git/hooks
    ln -sf ../../docs/git-hooks/commit-msg .git/hooks/commit-msg
    chmod +x docs/git-hooks/commit-msg docs/lint-commit-message.sh
    echo 'commit-msg 钩子已安装（jj 下不生效，用 just lint-msg）'

gc:
    sudo nix-collect-garbage -d --delete-older-than 3d
    nix store optimise

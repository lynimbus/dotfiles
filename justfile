default:
    @just --list

switch:
    nh os switch .

build:
    nh os build .

# 更新 flake.lock；变更永远落在 jj 栈顶的独立提交里
update:
    docs/update-flake-lock.sh

# 把滚动发布的自建包升到上游最新 release（nix-update 改写包文件里的
# version/hash/vendorHash 字面量；不带参数就全部包各跑一遍）
#   just bump            # 全部
#   just bump pig kero   # 指定包
bump *pkgs:
    docs/bump-packages.sh {{pkgs}}

check:
    nix flake check --no-build

# 用 nix-init 在临时目录里生成包骨架（不写进仓库），版本可省略
#   just scaffold https://github.com/owner/repo 1.2.3
scaffold url version="":
    #!/usr/bin/env bash
    set -euo pipefail
    # nix-init 解析 rev 时先跑 nix flake prefetch，自己又直接调 GitHub API，
    # 两条路都是匿名 60 次/小时/IP；把 gh keyring 里的 token 交给 nix。
    if token="$(gh auth token 2>/dev/null)"; then
        export NIX_CONFIG="access-tokens = github.com=$token"
    fi
    extra=()
    if [[ -n "{{version}}" ]]; then
        extra+=(-V "{{version}}")
    fi
    work="$(mktemp -d)"
    # 生成的是手稿、本就无需选择；而 nix-init 的 tag 选择提问在没有 TTY 的
    # 运行方（agent、CI）里读到 EOF 直接退出，所以永远走 --headless。
    nix-init --headless -u "{{url}}" "${extra[@]}" "$work/package.nix" || {
        echo "生成失败，目录保留：$work" >&2
        exit 1
    }
    echo
    echo "骨架：$work/package.nix"
    echo "移植进 pkgs/ 时去掉写死的 sha256 和 nix-update-script，把 version/hash 留作参数默认值"

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

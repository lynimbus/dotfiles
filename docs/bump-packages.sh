#!/usr/bin/env bash
# 把 pkgs/ 里的滚动发布包升到上游最新 release。
#
# 每个包的 version/hash 都是包文件里的字面量，由 nix-update 按包文件
# （--flake legacyPackages.<system>.<attr>）找到并整体改写：版本、资产
# hash、vendorHash、同文件的 --custom-dep 一次跑齐，不再有第二个版本
# 来源可以漂移。
#
# 用法：
#   docs/bump-packages.sh              # 全部滚动包
#   docs/bump-packages.sh pig kero      # 指定若干个
#
# nix-update 改写失败会留下「版本已换、hash 未换」的半途文件，直接
# jj restore pkgs/ 回滚再重试。
set -uo pipefail
cd "$(jj root)" || exit 1

# nix-update 探测新版默认走 releases.atom（无速率限制），预取 hash 交给
# nix；RELEASE_API_ONLY 的包例外。包文件指向 github.com 的 fetchurl 可能
# 撞上匿名限速，把 gh 的 token 交给 nix。
if token="$(gh auth token 2>/dev/null)"; then
  export NIX_CONFIG="access-tokens = github.com=$token"
fi

# 属性名 -> 需要一起走的 --custom-dep（同文件里的额外 fetcher）。
declare -A CUSTOM=(
  [kero]="tarball"
  [magpie]="upstream"
)

# 属性名 -> 不走默认的 releases.atom 而走 GitHub Releases API 的包：
# atom feed 把「推了 tag 还没发 release」也当新版（magpie 就这样），
# API 只认真 release。
declare -A RELEASE_API_ONLY=(
  [magpie]=1
)

ALL=(pig kero mygo opengrep rtk magpie strata)
if [[ $# -gt 0 ]]; then
  pkgs=("$@")
else
  pkgs=("${ALL[@]}")
fi

fail=()
for p in "${pkgs[@]}"; do
  args=()
  if [[ -n "${CUSTOM[$p]:-}" ]]; then
    args+=(--custom-dep "${CUSTOM[$p]}")
  fi
  if [[ -n "${RELEASE_API_ONLY[$p]:-}" ]]; then
    args+=(--use-github-releases)
  fi
  cmd=(nix run nixpkgs#nix-update -- --flake "legacyPackages.x86_64-linux.$p" "${args[@]}")
  if ! "${cmd[@]}"; then
    fail+=("$p")
    echo "[bump] $p 失败" >&2
  fi
done

if ((${#fail[@]})); then
  echo "[bump] 失败：${fail[*]}" >&2
  exit 1
fi

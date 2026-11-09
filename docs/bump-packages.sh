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
#
# 2026-11-09 的两个实测根因，决定了下面两处防御：
#
# (1) fetchurl 包会被 nix-update 无条件重取。sing-box 的 src 是 fetchurl，
#     derivation 里没有 rev/tag；--version-regex 剥掉 v 前缀后，nix-update
#     的 extract_version 仍把原始 tag 存进 new_version.rev，replace_version
#     用 changed = (old != new) or (new_version.rev is not None and
#     new_version.rev != old_rev_tag) 判断是否改写，而 old_rev_tag=None，
#     于是「版本没变」也恒为 changed，每次 bump 都要重下 31MB 的 release
#     资产来复核 hash。撞上 release-assets.githubusercontent.com 的瞬时
#     504（nix 内建 curl 的重试窗口只有 ~11s），整个 bump 就以 exit 1
#     告终——尽管文件里的 hash 本来就对。
#
#     → 重试只认网络/瞬时特征（502/503/504、cannot download、timed out、
#       curl 的 6/7/22/28 等）：这类失败换个时刻大概率就好；版本探测、
#       regex 无匹配、eval 失败、--build 校验失败是确定性错误，重试多少
#       次都一样，直接走既有失败路径。次数与间隔用 BUMP_RETRIES（额外
#       次数，默认 2）、BUMP_RETRY_DELAY（秒，默认 30）调整。
#
# (2) 预编译二进制包会在发布窗口里静默拿到陈旧字节。magpie v0.1.3370
#     发布约 10 分钟时，CDN 仍把旧版资产挂在新 tag 的 URL 上，nix-update
#     预取的 hash 恰好等于旧值（只有 version 行变了），bump exit 0；直到
#     just switch 构建时 versionCheckHook 才爆出来。nix-update 默认不构建
#     包，坏 pin 在 bump 阶段畅通无阻；--build 会在更新文件后重新拷贝整个
#     flake 到 store 再构建（options.py get_flake_import_path 的 “Always
#     re-copy”），让 package build + versionCheckHook 在 bump 当场跑一遍，
#     把这类 CDN 竞态拦在 bump 时刻。
#
#     → 只给依赖发布资产的预编译包（BUILD_VERIFY）追加 --build；源码构建
#       包的 vendorHash 流程已由 nix-update 自身覆盖，不需要额外构建。
set -uo pipefail
cd "$(jj root)" || exit 1

# nix-update 探测新版默认走 releases.atom（无速率限制），预取 hash 交给
# nix；RELEASE_API_ONLY 的包例外。包文件指向 github.com 的 fetchurl 可能
# 撞上匿名限速，把 gh 的 token 交给 nix；查 Releases API 的
# --use-github-releases 则是 nix-update 自己发请求，只认 GITHUB_TOKEN
# 环境变量，不导出就按匿名 60 次/小时/IP 计，限额一满即 403。
if token="$(gh auth token 2>/dev/null)"; then
  export NIX_CONFIG="access-tokens = github.com=$token"
  export GITHUB_TOKEN="$token"
fi

# 属性名 -> 需要一起走的 --custom-dep（同文件里的额外 fetcher）。
declare -A CUSTOM=(
  [kero]="tarball"
  [magpie]="upstream"
)

# 属性名 -> 额外的 nix-update 参数（用 read -ra 拆开，不做 glob 展开）。
# sing-box 跟上游 unstable 渠道（GitHub prerelease）：默认的 stable 偏好会
# 把 alpha/beta/rc 全部跳过，--version=unstable 放行；--version-regex 的
# 捕获组只匹配 prerelease tag 并顺带剥掉 v 前缀，稳定版全部筛掉，两者一起
# 才能把渠道钉死在 unstable 上。atom feed 只给最近 10 个 release，上游连
# 发多个稳定版时可能一个 prerelease 都不在里面，那会直接报错重跑即可。
declare -A EXTRA=(
  [sing-box]='--version=unstable --version-regex=v?(\d+\.\d+\.\d+-(?:alpha|beta|rc)\.\d+)'
)

# 属性名 -> 不走默认的 releases.atom 而走 GitHub Releases API 的包：
# atom feed 把「推了 tag 还没发 release」也当新版（magpie 就这样），
# API 只认真 release。
declare -A RELEASE_API_ONLY=(
  [magpie]=1
)

# 属性名 -> bump 后追加 --build 做构建校验的包。只有预编译二进制（发布
# 资产）包才需要：CDN 发布窗口里的陈旧字节竞态只会伤这类包的预取 hash；
# 源码构建包（vendorHash 那一类）已由 nix-update 自身的改写/校验流程
# 覆盖，不必再构建一遍。
declare -A BUILD_VERIFY=(
  [magpie]=1
  [sing-box]=1
)

# 网络/瞬时失败特征：只有 log 命中这里才重试，其余错误一律直接失败。
NET_RETRY_RE='502|503|504|cannot download|failed to retrieve hash|timed out|Failed to connect|Connection reset|curl: \((6|7|22|28)\)'

BUMP_RETRIES="${BUMP_RETRIES:-2}"
BUMP_RETRY_DELAY="${BUMP_RETRY_DELAY:-30}"

# 跑一次 nix-update，stdout+stderr 实时 tee 到每包临时 log（既保留终端
# 输出，又能在失败后判断是不是网络特征）。rc 取 PIPESTATUS[0]，tee 的
# 退出码不参与判断。
run_nix_update() {
  local p="$1"
  shift
  local log attempt=0 rc
  log="$(mktemp)" || return 1
  while :; do
    attempt=$((attempt + 1))
    "$@" 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}
    if ((rc == 0)); then
      rm -f "$log"
      return 0
    fi
    # 重试用尽：交给调用方的既有失败路径。
    if ((attempt > BUMP_RETRIES)); then
      rm -f "$log"
      return "$rc"
    fi
    # 确定性错误不重试。
    if ! grep -qiE -- "$NET_RETRY_RE" "$log"; then
      rm -f "$log"
      return "$rc"
    fi
    echo "[bump] $p 第 $attempt 次失败（网络/瞬时），${BUMP_RETRY_DELAY}s 后重试（第 $((attempt + 1))/$((BUMP_RETRIES + 1)) 次尝试）" >&2
    sleep "$BUMP_RETRY_DELAY"
  done
}

ALL=(pig kero mygo opengrep rtk magpie strata sing-box)
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
  if [[ -n "${EXTRA[$p]:-}" ]]; then
    read -r -a extra <<< "${EXTRA[$p]}"
    args+=("${extra[@]}")
  fi
  if [[ -n "${RELEASE_API_ONLY[$p]:-}" ]]; then
    args+=(--use-github-releases)
  fi
  if [[ -n "${BUILD_VERIFY[$p]:-}" ]]; then
    args+=(--build)
  fi
  cmd=(nix run nixpkgs#nix-update -- --flake "legacyPackages.x86_64-linux.$p" "${args[@]}")
  if run_nix_update "$p" "${cmd[@]}"; then
    echo "[OK] $p 成功"
  else
    fail+=("$p")
    echo "[bump] $p 失败" >&2
    echo "[bump] $p 的文件可能已改一半（版本已写、hash 未写），可 jj restore pkgs/ 回滚后重试" >&2
  fi
done

if ((${#fail[@]})); then
  echo "[bump] 失败：${fail[*]}" >&2
  exit 1
fi

#!/usr/bin/env bash
# 自动更新 pkgs/zed-prebuilt.nix 到 zed 官方最新 stable release。
# 用法：just update-zed（推荐）或直接执行本脚本。
# 流程：GitHub API 查最新 release tag → 临时下载官方预编译 zip 算 hash →
#       用 sed 更新文件顶部的 ver/zipHash → 删除临时文件。
# 之后照常 just check → just switch。
set -euo pipefail

cd "$(dirname "$0")/.."
PKG=pkgs/zed-prebuilt.nix

tag=$(curl -s https://api.github.com/repos/zed-industries/zed/releases/latest \
  | jq -r '.tag_name // empty')
if [[ -z "$tag" ]]; then
  echo "错误：无法从 GitHub API 获取最新 release tag" >&2
  exit 1
fi
ver=${tag#v}
url="https://github.com/zed-industries/zed/releases/download/${tag}/zed-linux-x86_64.tar.gz"

echo "最新 release: $tag（v$ver）"
echo "下载并计算 hash: $url"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
hash=$(nix store prefetch-file --unpack --json "$url" | jq -r '.hash')

echo "hash: $hash"

# 更新 pkgs/zed-prebuilt.nix 顶部的 ver 与 zipHash 常量
sed -i -E \
  -e "s/^  ver = \".*\";/  ver = \"$ver\";/" \
  -e "s|^  zipHash = \"sha256-[A-Za-z0-9+/=]*\";|  zipHash = \"$hash\";|" \
  "$PKG"

echo "已更新 $PKG（ver=$ver, zipHash=$hash）"
echo "下一步：just check && just switch"
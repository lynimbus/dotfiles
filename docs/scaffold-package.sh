#!/usr/bin/env bash
# 用 nix-init 生成新包骨架，直接落成 pkgs/ 里的同款形式：
#
#   - version/hash（含 vendorHash/cargoHash 这类依赖 hash）从包体字面量
#     提为带默认值的函数参数。docs/bump-packages.sh 的 nix-update 按包文件
#     整体改写，参数默认值和普通赋值一样能被它找到（pig/kero 全是这个
#     形状），这是滚动包能一把 bump 的前提。
#   - 去掉 nix-update-script（参数行 + passthru.updateScript）：bump 走
#     `nix-update --flake legacyPackages.<system>.<attr>`，不靠包内
#     updateScript；空的 maintainers 一并去掉（本仓库不维护该字段）。
#   - finalAttrs 收拢为直接引用：version 已是参数，changelog 里的
#     ${finalAttrs.src.tag} 换成同一个 tag 表达式，mkDerivation 的
#     finalAttrs lambda 去掉（现有 pkgs/ 全是直引形状）。
#   - 产物写进 pkgs/<name>.nix，按字母序接进 overlay.nix。
#
# 用法：
#   docs/scaffold-package.sh https://github.com/owner/repo [version]
#
# 骨架只保证「能求值、能被 bump 改写」：构建阶段（installPhase 等）和
# meta.description 由人按项目实际补——nix-init 对非编译型项目只会给出
# 空骨架（noop 那种 bun 直跑的 TypeScript 就是）。
set -euo pipefail
cd "$(jj root)" || exit 1

url="${1:?用法：docs/scaffold-package.sh <url> [version]}"
version="${2:-}"

# nix-init 解析 rev 时先跑 nix flake prefetch，自己又直接调 GitHub API，
# 两条路都是匿名 60 次/小时/IP；把 gh keyring 里的 token 交给 nix。
if token="$(gh auth token 2>/dev/null)"; then
  export NIX_CONFIG="access-tokens = github.com=$token"
fi

# 属性名取 URL 末段（转小写、须是合法 Nix 标识符），只作 overlay 的键和
# 文件名；pname 由 nix-init 按项目自己的构建元数据推导，两者可以不同。
name="$(basename "${url%/}")"
name="${name%.git}"
name="${name,,}"
if [[ ! "$name" =~ ^[a-z][a-z0-9_-]*$ ]]; then
  echo "从 URL 末段推不出合法属性名：$name（请手工放置并接进 overlay）" >&2
  exit 1
fi
if [[ -e "pkgs/$name.nix" ]]; then
  echo "pkgs/$name.nix 已存在，不覆盖" >&2
  exit 1
fi

extra=()
if [[ -n "$version" ]]; then
  extra+=(-V "$version")
fi

work="$(mktemp -d)"
# 生成的是手稿、本就无需选择；而 nix-init 的 tag 选择提问在没有 TTY 的
# 运行方（agent、CI）里读到 EOF 直接退出，所以永远走 --headless。
if ! nix-init --headless -u "$url" "${extra[@]}" "$work/package.nix"; then
  echo "生成失败，目录保留：$work" >&2
  exit 1
fi
pkg="$work/package.nix"

# ---- (1) nix-update-script：参数行和 passthru 行整行去掉 ----
sed -i '/nix-update-script/d' "$pkg"

# ---- (2) version 字面量提为参数默认值 ----
ver="$(sed -n 's/^  version = "\([^"]*\)";$/\1/p' "$pkg")"
sed -i '/^  version = "/d' "$pkg"

# ---- (3) hash 类字面量提为参数默认值，原位换成 inherit ----
# fetcher 认 hash 这个通用名，sha256 一并并入 hash；vendorHash/cargoHash
# 这类依赖 hash 各自成参数（kero 的形状）。同名出现多次时只提第一个，
# 其余 inherit 指向同一个参数必然炸 hash，留给人工合并。
names=()
lines=()
nlines=0
while read -r attr value; do
  param="$attr"
  if [[ "$attr" == sha256 ]]; then
    param="hash"
  fi
  dup=0
  for n in "${names[@]}"; do
    if [[ "$n" == "$param" ]]; then
      dup=1
    fi
  done
  if ((dup)); then
    echo "警告：$param 出现多次，只提第一个为参数，其余请人工合并" >&2
  else
    names+=("$param")
    lines+=("  $param ? \"$value\",")
    nlines=$((nlines + 1))
  fi
  sed -i "s|^\([[:space:]]*\)$attr = \"$value\";|\1inherit $param;|" "$pkg"
done < <(sed -n 's/^[[:space:]]*\(sha256\|[A-Za-z0-9_-]*[Hh]ash\) = "\(sha256-[^"]*\)";$/\1 \2/p' "$pkg")

# 漏网的 sha256 字面量会让 bump 契约破洞（nix-update 改不到它），
# 宁可当场失败也不静默留下写死的 hash。
if grep -q '= "sha256-' "$pkg"; then
  echo "有 sha256 字面量没提成参数，人工处理后再放置：" >&2
  grep -n '= "sha256-' "$pkg" >&2
  echo "文件保留：$work" >&2
  exit 1
fi

# ---- (4) finalAttrs 收拢为直接引用 ----
sed -i 's/finalAttrs\.version/version/g' "$pkg"
tag_expr="$(sed -n -e 's/^[[:space:]]*tag = \(.*\);$/\1/p' -e 's/^[[:space:]]*rev = \(.*\);$/\1/p' "$pkg" | head -1)"
if [[ -n "$tag_expr" ]]; then
  bare="${tag_expr%\"}"
  bare="${bare#\"}"
  # changelog 里的引用是插值语境：裸标识符（如 version）要包回
  # ${...}，已含插值（v${version}）或字面 tag 的原样使用。
  ident_re="^[a-zA-Z_][a-zA-Z0-9_-]*$"
  if [[ "$bare" =~ $ident_re ]]; then
    bare="\${$bare}"
  fi
  sed -i "s|\${finalAttrs\.src\.tag}|$bare|g" "$pkg"
  # fetchFromGitHub 里 rev 与 tag 同值，nix-init 的 changelog 模板两种
  # 引用都会用，统一换成同一个表达式。
  sed -i "s|\${finalAttrs\.src\.rev}|$bare|g" "$pkg"
fi
sed -i -e 's/(finalAttrs: {/{/' -e '$s/^})$/}/' "$pkg"
if grep -q 'finalAttrs' "$pkg"; then
  echo "警告：仍有 finalAttrs 残留（如 rev 形式的 tag），人工核对 $pkg" >&2
fi

# ---- (5) 空 maintainers 去掉 ----
sed -i -E '/^[[:space:]]*maintainers = (with lib\.maintainers; )?\[ \];$/d' "$pkg"

# ---- (6) 参数块插进函数头（工具参数之后、`}:` 之前） ----
{
  printf '  # The version and every hash below are pinned by the same release\n  # tag: `just bump %s` (nix-update) rewrites all these literals in\n  # this file together.\n' "$name"
  if [[ -n "$ver" ]]; then
    echo "  version ? \"$ver\","
  fi
  if [[ "$nlines" -gt 0 ]]; then
    printf '%s\n' "${lines[@]}"
  fi
} > "$work/params"

awk -v params="$work/params" '
  BEGIN { while ((getline l < params) > 0) b[++n] = l; close(params) }
  /^}:$/ && !ins { for (i = 1; i <= n; i++) print b[i]; ins = 1 }
  { print }
' "$pkg" > "$work/styled.nix" && mv "$work/styled.nix" "$pkg"

# ---- (7) 落盘 + 按字母序接进 overlay.nix ----
# 删行（version/passthru/maintainers）留下的连续空行收敛掉。
cat -s "$pkg" > "$work/squeezed.nix" && mv "$work/squeezed.nix" "$pkg"
mv "$pkg" "pkgs/$name.nix"

line="  $name = final.callPackage ./pkgs/$name.nix { };"
LC_ALL=C awk -v line="$line" -v name="$name" '
  {
    if (!done && /^  [A-Za-z0-9_-]+ = final\.callPackage/) {
      cur = $0
      sub(/^  /, "", cur)
      sub(/ = .*/, "", cur)
      if (cur > name) { print line; print ""; done = 1 }
    }
    # 排最后的属性名没有任何条目可比它大，收尾 } 前是它的位置。
    if (!done && /^}$/) { print line; print ""; done = 1 }
    print
  }
' overlay.nix > "$work/overlay.nix" && mv "$work/overlay.nix" overlay.nix

rm -rf "$work"

echo
echo "已生成 pkgs/$name.nix 并接入 overlay.nix。"
if grep -q 'description = "";' "pkgs/$name.nix"; then
  echo "⚠ meta.description 为空，记得补上。"
fi
echo "接下来："
echo "  1. 按项目实际补构建阶段（骨架只保证求值形状，不保证能构建）"
echo "  2. nix build .#legacyPackages.x86_64-linux.$name 验证"
echo "  3. 若随上游滚动发布，把 $name 加进 docs/bump-packages.sh 的 ALL 列表"

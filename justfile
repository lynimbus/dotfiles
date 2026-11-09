default:
    @just --list

switch:
    nh os switch .

build:
    nh os build .

update:
    env NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix flake update

# 把滚动发布的自建包升到上游最新 release（nix-update 改写包文件里的
# version/hash/vendorHash 字面量；不带参数就全部包各跑一遍）
#   just bump            # 全部
#   just bump pig kero   # 指定包
bump *pkgs:
    docs/bump-packages.sh {{pkgs}}

check:
    nix flake check --no-build

# 用 nix-init 生成新包骨架，直接落成 pkgs/ 里的同款形式（version/hash
# 提为参数默认值、去掉 nix-update-script、按字母序接进 overlay.nix），
# 版本可省略
#   just scaffold https://github.com/owner/repo 1.2.3
scaffold url version="":
    docs/scaffold-package.sh "{{url}}" "{{version}}"

gc:
    sudo nix-collect-garbage -d --delete-older-than 3d
    nix store optimise

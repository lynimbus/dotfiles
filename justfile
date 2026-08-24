# NixOS flake 常用命令入口（host = flakeos）
# 用法：just <目标>；无参数列出所有目标

host := "flakeos"

default:
    @just --list

# 部署当前锁版本（nh 内部自行提权）
switch:
    nh os switch .

# 只构建校验，不切换
build:
    nh os build .

# 写入引导项，下次开机生效（适合内核/驱动变更）
boot:
    nh os boot .

# 升级 flake.lock 并部署
update:
    nix flake update
    nh os switch .

# 只更新单个 input，例如：just update-input nixpkgs
update-input input:
    nix flake update {{input}}

# 求值校验 flake 结构，不构建
check:
    nix flake check --no-build

# 格式化本仓库 Nix 文件（nixfmt）
fmt:
    nix fmt

# 回滚到上一代
rollback:
    sudo nixos-rebuild switch --rollback --flake .#{{host}}

# 部署历史
generations:
    nixos-rebuild list-generations

# 对比当前系统与新构建的包版本差异（nh 内置 nvd）
diff:
    nh os build . --diff always

# 对比任意两代系统，例：just diff-gen 22 23
diff-gen a b:
    nvd diff /nix/var/nix/profiles/system-{{a}}-link /nix/var/nix/profiles/system-{{b}}-link

# 回收垃圾并硬链接去重
gc:
    sudo nix-collect-garbage -d --delete-older-than 14d
    nix store optimise

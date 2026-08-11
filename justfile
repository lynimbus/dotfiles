# nix-config 常用命令（更新 / 部署 / 清理）
# 用法：`just`（= 第一条 recipe update）或 `just <recipe>`

# 更新 nixpkgs/home-manager 锁版本并部署（日常「一条命令更新」）
update:
    nix flake update
    home-manager switch --flake .

# 仅部署当前锁版本（不更新，日常改配置后快速应用）
switch:
    home-manager switch --flake .

# 仅构建校验，不切换（检查配置是否写错）
build:
    home-manager build --flake .

# 回滚到上一代（出问题时的安全网）
rollback:
    home-manager rollback

# 查看部署历史
generations:
    home-manager generations

# 清理 store 垃圾并去重
gc:
    nix-collect-garbage -d
    nix store optimise

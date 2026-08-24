# flakeos —— NixOS 配置

单主机 NixOS flake：nixpkgs `nixos-unstable` + home-manager（作为 NixOS module 集成）+ nixos-hardware。

- 主机 `flakeos`，用户 `lynimbus`，系统 `x86_64-linux`
- 桌面 KDE Plasma 6（Wayland，SDDM）+ fcitx5/rime-ice 输入法 + PipeWire
- 硬件 profile：`nixos-hardware.nixosModules.mechrevo-gm5hg0a`
- 部署工具 `nh`，格式化 `nixfmt`，命令入口 `justfile`

面向 AI agent 与日常操作的详细约定见 [AGENTS.md](AGENTS.md)。

## 目录结构

```
.
├── flake.nix                          # inputs / outputs，host 列表、用户名邮箱在这里
├── flake.lock                         # 锁文件（nix flake update 更新，勿用 sudo）
├── justfile                           # 常用命令入口
├── AGENTS.md                          # 仓库约定：改哪个文件、部署流程、硬约定
├── hosts/flakeos/
│   ├── configuration.nix              # 系统层：内核/引导/桌面/服务/locale/nix 设置
│   └── hardware-configuration.nix     # nixos-generate-config 生成，勿手改
├── home/
│   └── flakeos.nix                    # 用户层：home.packages 与 programs.*（git/jj…）
└── inputs/
    └── sing-box-ref1nd-flake/         # vendored flake（自建包）
```

## 常用命令

```bash
just             # 列出所有目标
just switch      # 部署（nh os switch .）
just build       # 只构建校验
just check       # nix flake check --no-build，秒级求值校验
just update      # nix flake update + 部署
just diff        # nvd 对比当前系统与新构建的包版本差异
just rollback    # 回滚上一代
just generations # 部署历史
just fmt         # nix fmt
just gc          # 回收 14 天前的代 + store optimise
```

裸命令等价物：`sudo nixos-rebuild switch --flake .#flakeos`。

## 加软件

用户级（绝大多数情况）改 `home/flakeos.nix` 的 `home.packages`；系统级改 `hosts/flakeos/configuration.nix` 的 `environment.systemPackages`。加之前先 `nix eval nixpkgs#<pkg>.version` 确认包名，然后 `just check` → `just switch`。

有 home-manager module 的程序（`programs.<name>`）优先走 module，能一并托管配置文件。

## 扩展点

- **新机器**：`flake.nix` 的 `hosts` 列表加一项 + 建 `hosts/<name>/` 与 `home/<name>.nix`。
- **共享模块**：重复配置抽到 `modules/`，在 `mkSystem` 的 `modules` 里引入。
- **私有包/覆盖层**：启用 `flake.nix` 里注释掉的 `overlays.default`，用 `final.callPackage` 注入。
- **机密管理**：引入 `sops-nix`，把 secrets 托管给 `age`/`sops`。
- **声明式分区**：引入 `disko`，换机可秒级重建磁盘布局。
- **换稳定通道**：`nixpkgs.url` 改成 `github:NixOS/nixpkgs/nixos-26.05`（注意 home-manager 需换到对应 release 分支）。

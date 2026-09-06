---
name: nix-usage
description: 本机（NixOS 26.11 unstable / Nix 2.34.8，配置仓 ~/dotfiles，host flakeos）的 Nix 配置与部署专属知识：改哪个文件、用哪条 just 命令、home-manager 作为 NixOS module 的约束、本机踩过的坑与排查流程。当涉及修改本机配置、装包、部署、回滚、排查本机构建或求值失败时使用。通用 Nix 语言语法、flake schema、nix CLI 用法、nixpkgs 打包教程请改用 nixos skill。
---

# 本机 Nix / NixOS 工作流（~/dotfiles）

> **分工**：通用 Nix/NixOS 知识（语言语法、flake schema、module system 教程、打包、nix CLI 全量用法）在 `nixos` skill，那份由上游 CI 每日从 nix.dev / nixpkgs manual / nix-pills 同步。
> **本文只写上游文档不可能知道的事**：这台机器的结构、约定、命令入口，以及在这台机器上真实踩过的坑。
>
> 两者触发范围有重叠（`nixos` 的 description 也含 `nixos-rebuild`、`home-manager`、`configuration.nix`）。判据：**要动这台机器上的文件或跑部署命令 → 本文优先**，因为上游文档给的通用做法在本机有若干不成立之处（最典型：本机没有 `home-manager switch`，见下）。纯概念与语法问题走 `nixos`。
>
> 事实基线校对于 2026-09-06。版本号会漂，**结构性事实（module 形式、文件职责、命令入口）才是本文的价值**；版本号仅供判断“文档是否该重新核对”。

---

## 1. 事实基线

- **NixOS 26.11**（`nixos-version` → `26.11.20260905.c043004` Zokor），nixpkgs 跟 **nixos-unstable**。
- `stateVersion = "26.05"`（系统层与 home 层各一份）只是兼容基线，**不代表通道**，不要为了“升级”去改它。
- Nix **2.34.8**，`nh` **4.4.2**，`nix fmt` → nixfmt **2.6.0**。
- 配置仓 `~/dotfiles`，host = `flakeos`，用户 `lynimbus`，`x86_64-linux`。
- `~/dotfiles` 用 **jj colocate** 管理（`.jj` + `.git` 并存）。
- 实验特性 `nix-command`、`flakes` 由 `nix.settings` 写入；`nix config show` 的生效值还含 NixOS 隐式开启的 `fetch-tree`。

### 最要紧的一条：home-manager 是 NixOS module

本机用 `home-manager.nixosModules.home-manager` + `home-manager.users.<u>`，**没有 standalone `homeConfigurations`**：

- **不存在 `home-manager switch`** —— 用户层改动同样走 `nixos-rebuild` / `nh os switch`。
- `specialArgs`（系统层）与 `extraSpecialArgs`（home 层）是**两套，不共享**。
- 代价：只改 home 层也要重新求值整个系统闭包，求值本来就慢，这是该集成方式的固有成本，不是出问题了。

从 Arch 时代 standalone home-manager 迁过来最容易在这里犯错。

---

## 2. 仓库结构

```
~/dotfiles/
├── flake.nix        # inputs: nixpkgs(nixos-unstable) + home-manager/nixos-hardware/deepseek-harness
│                    #         + niri-flake/niri-glass + mac-style-plymouth + zig-overlay
│                    #         + nixos-ai-skill(flake=false，pi 的通用 NixOS 文档 skill)
│                    # outputs: nixosConfigurations.flakeos、formatter=nixfmt
│                    # 顶层 let 定义 system/username/email，经 specialArgs 与 extraSpecialArgs 下传
│                    # overlay 在顶层 let 里定义（glassOverlay 打 niri liquid-glass 补丁、zedOverlay 换预编译 zed）
├── flake.lock
├── justfile         # 唯一命令入口，见 §4
├── AGENTS.md        # 仓库硬约定
├── hosts/flakeos/
│   ├── configuration.nix          # 系统层：引导/内核/桌面/输入法/PipeWire/locale/nix.settings/nix.gc/programs.nh
│   └── hardware-configuration.nix # nixos-generate-config 生成，勿手改
├── home/flakeos.nix               # 用户层：home.packages + programs.* + home.file
└── pkgs/zed-prebuilt.nix          # 官方 release 预编译 zed
```

## 3. 决策矩阵：改哪个文件

| 场景 | 做法 |
|---|---|
| 内核、引导、系统服务、桌面/登录管理器、输入法、字体、locale、nix 设置 | `hosts/flakeos/configuration.nix` |
| 用户级软件与程序配置（有 `programs.<name>` module 就用 module，别手写配置文件） | `home/flakeos.nix` |
| flake input、用户名邮箱、overlay | `flake.nix` |
| 临时用一次 | `nix shell nixpkgs#<pkg>` / `nix run nixpkgs#<pkg>` |
| nixpkgs 没有该包 | 自建包放 `pkgs/`，在 `flake.nix` overlay 里 `final.callPackage` 注入 |
| 上游只发 AppImage / 预编译二进制 | `pkgs.appimageTools.wrapType2` 或 `buildFHSEnv`；跑闭源二进制用 `steam-run` |
| nixpkgs 版本滞后 | 覆盖 `src`/`version` 的 overlay，或临时 `nix run github:owner/repo` |

判据：**登录前就要存在的东西**（内核、显示管理器、系统服务、全局 PATH）进系统层；**只服务当前用户的东西**进 home 层。拿不准优先 home —— 回滚粒度更细，不必重建整个系统闭包。

## 4. 日常命令（justfile 是入口）

```bash
just switch      # nh os switch .        部署（nh 自行提权，无需手写 sudo）
just build       # nh os build .         只构建校验
just boot        # nh os boot .          写引导项，下次开机生效（内核/驱动变更）
just update      # nix flake update && nh os switch .
just update-input <input>  # 只更新单个 input
just check       # nix flake check --no-build   秒级求值校验，改完先跑这个
just diff        # nh os build . --diff always  （nh 内置 nvd 包版本差异）
just diff-gen a b # nvd diff 任意两代系统 profile
just rollback    # sudo nixos-rebuild switch --rollback --flake .#flakeos
just generations # nixos-rebuild list-generations（无需 sudo）
just fmt         # nix fmt
just gc          # sudo nix-collect-garbage -d --delete-older-than 14d && nix store optimise
just dsh-web     # 从服务日志取最新认证 URL 并用浏览器打开
```

裸命令等价物：`sudo nixos-rebuild switch --flake .#flakeos`。

改动后的推荐顺序：`just check`（秒级，抓语法与选项名错误）→ `just build`（真构建）→ `just switch`。危险改动用 `nixos-rebuild test`（只生效不写引导，重启即消）。

---

## 5. 本机踩过的坑

- **`nix flake update` 绝不加 sudo**：会把 `flake.lock` 属主改成 root，之后普通用户改不动（本机踩过）。修复：`sudo chown lynimbus:users flake.lock`。
- **二进制缓存必须写进 `configuration.nix` 的 `nix.settings`**，不能只写 `flake.nix` 的 `nixConfig` —— 后者只对 `trusted-users` 生效，而本机 `trusted-users` 只有 root，普通用户跑 `nix build` 会看到 "ignoring untrusted substituter" 然后全部本地编译。临时救急 `--accept-flake-config`（仍受 trusted-users 限制）。
- **`nix.gc` 与 `programs.nh.clean` 只能开一个**（都是定时清理，NixOS module 有 assertion）。本机用 `nix.gc`（weekly、`--delete-older-than 14d`）。
- **托管文件是 /nix/store 符号链接**：改配置一律改 flake 源文件 → `just switch`，**勿手改 ~/.config**。home-manager 遇到已存在的真实文件按 `backupFileExtension = "bak"` 改名让路，别把 `.bak` 当配置改。
- **unstable 上 home-manager 选项改名频繁**（实测 `programs.git.userName/userEmail/extraConfig` → `programs.git.settings.{user.name,user.email,…}`）。`just check` 打出的 `evaluation warning: ... has been renamed to ...` 是下次升级会变硬错误的地方，**别忽略**。
- **`nix-collect-garbage -d` 删旧代就回不去了**：回滚的本质是指向旧 profile 代，旧代被 GC 后安全网就没了。升级后先跑一阵再 gc。
- 装包前确认 `nix eval nixpkgs#<pkg>.version`；包名偶有出入（`delta`、`yq-go`）。
- 部署后验证 `command -v <pkg>` 应指向 `/nix/store`（用户层经 `/etc/profiles/per-user/<u>/bin` 转一跳）。
- **specialisation `battery-saver`**（来自 nixos-hardware 的 mechrevo-gm5hg0a profile）：`nixos-rebuild list-generations` 的 Specialisation 列可见；临时切换 `sudo /run/current-system/specialisation/battery-saver/bin/switch-to-configuration test`。

---

## 6. 本机排查流程

**查选项的生效值与定义**，比翻文档快且不会因上游改名而过时：

```bash
nix eval .#nixosConfigurations.flakeos.config.<路径>
nix eval .#nixosConfigurations.flakeos.options.<路径>.{description,default,type.description}
# home 层在 config.home-manager.users.lynimbus.<路径> 下
```

对症下药：

- **`The option 'xxx' does not exist`**：`nix eval .#nixosConfigurations.flakeos.options.<父路径> --apply builtins.attrNames` 列真实选项名。
- **`assertion failed`**：module 的 `assertions` 机制，报文即原因（典型：`nix.gc` 与 `programs.nh.clean` 同时开）。
- **标量选项多处定义冲突**：`lib.mkForce` 覆盖 / `lib.mkDefault` 让位。
- **infinite recursion**：`config` 是合并后的最终结果，读 `config.x` 又去定义 `x` 的前提就会绕回来。
- **改了配置但服务没变**：`systemctl status <unit>` 看它指向的 store path，对比 `/run/current-system`；`switch-to-configuration` 只重启它认为变了的 unit，其余手动 restart。
- **求值/构建失败**：`--show-trace` 看求值栈；`-L` 看完整构建日志；`--keep-failed` 保留现场。
- **依赖莫名被带进闭包**：`nix why-depends --precise <pkg> <dep>`。

运维常用：

```bash
nvd diff /nix/var/nix/profiles/system-{22,23}-link   # 两代差异（系统 profile，不是用户 profile）
nix path-info -Sh /nix/store/* | sort -k2 -h | tail  # store 用量大头
```

本机已开 `auto-optimise-store`（自动硬链接去重）与 `warn-dirty = false`（jj 下工作副本常脏，免每次警告）。

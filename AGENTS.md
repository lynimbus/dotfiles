# dotfiles —— NixOS flake 配置仓约定

本仓是**唯一的系统与用户环境事实来源**。除临时试用，任何软件与配置变更都必须落到这里的 `.nix` 文件，再部署生效。

## 基本事实

- 主机名 / flake 属性：`flakeos`（`nixosConfigurations.flakeos`）
- 用户：`lynimbus`，系统 `x86_64-linux`
- nixpkgs：`nixos-unstable`（**不是**稳定分支；`stateVersion = "26.05"` 只是兼容基线，不代表通道）
- home-manager：以 **NixOS module** 方式集成，**没有** standalone 的 `homeConfigurations`
  → 因此**不存在 `home-manager switch`**，用户层改动同样走 `nixos-rebuild` / `nh os switch`
- 版本控制：**jj colocate**（`.jj` 与 `.git` 并存）。日常提交、改历史用 jj；推拉用 `jj git`
- 格式化器：`nix fmt` → nixfmt

## 改哪个文件

| 目标 | 文件 |
|---|---|
| 内核、引导、服务、桌面、输入法、网络、locale、nix 设置 | `hosts/flakeos/configuration.nix` |
| 用户级软件、dotfile、程序配置（git/jj/编辑器…） | `home/flakeos.nix` |
| flake input、host 列表、用户名/邮箱、overlay、formatter | `flake.nix` |
| 硬件探测结果 | `hosts/flakeos/hardware-configuration.nix`（**别手改**，由 `nixos-generate-config` 生成） |
| 自建包 / vendored flake | `inputs/<name>-flake/` |

系统层与用户层的判据：**登录前就要存在的东西**（内核、显示管理器、系统服务、字体、全局 PATH）进 `configuration.nix`；**只服务于这个用户的东西**进 `home/flakeos.nix`。拿不准优先放 home，用户层可回滚粒度更细。

## 部署

```bash
just switch      # nh os switch .        日常部署（nh 内部自行提权）
just build       # nh os build .         只构建校验
just boot        # nh os boot .          写引导项，下次开机生效（内核/驱动变更用）
just update      # nix flake update + switch
just check       # nix flake check --no-build   只求值，最快的语法/选项校验
just diff        # nvd 对比当前系统与新构建的包版本（nh 内置）
just diff-gen 22 23   # 对比任意两代系统 profile
just rollback    # 回上一代
just gc          # nix-collect-garbage -d --delete-older-than 14d + store optimise
```

裸命令等价物：`sudo nixos-rebuild switch --flake .#flakeos`。

## 硬约定

1. **禁止手改 `~/.config` 下由 home-manager 托管的文件**——它们是指向 `/nix/store` 的符号链接，只读，且下次部署会被覆盖。改源文件再部署。
2. **`nix flake update` 不要加 sudo**。加了会把 `flake.lock` 属主改成 root，之后普通用户改不动。若已发生：`sudo chown lynimbus:users flake.lock`。
3. **改完先 `just check`**（秒级求值校验），再 `just build`，最后才 `just switch`。选项拼错、option 改名都能在 check 阶段暴露。
4. **不要贸然 `just switch` 后不验证**。装了新包就确认 `command -v <pkg>` 指向 `/nix/store`。
5. **二进制缓存写在 `configuration.nix` 的 `nix.settings`**，不是只写 `flake.nix` 的 `nixConfig`——后者只对 `trusted-users` 生效，而本机 `trusted-users` 只有 root。
6. **`nix.gc` 与 `programs.nh.clean` 只能开一个**（两者都是定时清理，NixOS module 有 assertion）。当前用 `nix.gc`。
7. home-manager 在 unstable 上选项改名频繁（如 `programs.git.userName` → `programs.git.settings.user.name`）。**`just check` 输出的 evaluation warning 不要忽略**，那是下次升级会变硬错误的地方。

## 加包的正确姿势

```bash
nix eval nixpkgs#<pkg>.version     # 先确认包名存在、版本合意（包名常有出入：yq-go、delta…）
nix run nixpkgs#<pkg>              # 临时试一次，不入配置
```
确定要长期用 → 加进 `home/flakeos.nix` 的 `home.packages`（或 `configuration.nix` 的 `environment.systemPackages`，若是系统级）→ `just check` → `just switch`。

程序若有 home-manager module（`programs.<name>`），**优先用 module 而不是塞进 packages**：module 能同时托管配置文件。

## 提交

改完用 jj 提交，`flake.lock` 更新单独开 commit。

**LLM（agent）发起的提交，信息一律用 `llm: 内容` 形式**；用户自己提交的内容保持原样。

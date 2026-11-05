# NixOS → atomic 移植映射

> 本文记录 main 分支（NixOS flake）的每一项配置与软件包在本分支（atomic/
> Bazzite）上的去向。重建 atomic 配置时逐模块核对过（2026-11）。

## 原则

* **镜像层（`Containerfile` / `build_files/build.sh` / `system_files/`）**：会话、
  字体、输入法、音频、系统服务——NixOS `system/` 模块的落点。
* **chezmoi 层（`home/chezmoi/`）**：用户配置——NixOS `home/`（home-manager）的
  落点，大多为原样移植。
* **brew / flatpak / release 脚本**：软件包——NixOS `home.packages` 与 `pkgs/`
  overlay 的落点。
* NixOS 特有（bootloader、Nix 工具链、sops-nix）无法逐字移植，下表逐一说明。

## system/ 模块

| main 模块 | atomic 落点 | 说明 |
|---|---|---|
| `boot.nix`（systemd-boot、quiet 内核参数、latest kernel + zenpower） | — | bootc 的内核与引导由基础镜像管理。zenpower 可在运行时自行 layer（copr `ublue-os:akmods` 里有 `akmod-zenpower3`），为避免每日构建绑死内核版本不进镜像 |
| `network.nix` | — | NetworkManager 已是 Bazzite 默认 |
| `ssh.nix` | `system_files/etc/ssh/sshd_config.d/50-atomic-workstation.conf` + build.sh `systemctl enable sshd` | 仅密钥登录；主机密钥留在机器状态里 |
| `locale.nix` | `system_files/etc/locale.conf` | en_US + zh_CN 区域格式 |
| `fonts.nix` | build.sh：dnf 字体包 + 下载 Maple Mono NF CN / JetBrainsMono Nerd Font | Noto CJK、Fira Code、Intel One Mono 走 dnf；两个 NF 字体 Fedora 没有打包，按 sha256 固定版本下载 |
| `input-method.nix`（fcitx5 + rime-ice） | build.sh：fcitx5 全家桶 + `system_files/etc/environment.d/60-fcitx5.conf` | rime-ice 词库是用户数据：装到 `~/.local/share/fcitx5/rime`（见下） |
| `audio.nix` | — | PipeWire/WirePlumber 是 Bazzite 基础镜像的一部分 |
| `hardware.nix` | `system_files/etc/systemd/system/var-mnt-{windows,data}.{mount,automount}` | NTFS 挂载按同样的 UUID/参数移植为 systemd 挂载单元；`/mnt/data` 额外加 `nofail` 防止缺盘卡启动。**单元名用规范化路径 `var-mnt-*`、`Where=/var/mnt/*`**：ostree 上 `/mnt -> var/mnt` 是符号链接，systemd 拒绝经由符号链接的挂载点（`Mount path … is not canonical`），`systemd-fstab-generator` 对 fstab 也是这么命名的。zram/蓝牙/tuned 已是 Bazzite 默认（tuned 在镜像里显式 enable） |
| `ollama.nix` | build.sh：dnf `ollama-base` + `ollama-vulkan` + `system_files/.../ollama.service.d/10-lynimbus.conf` | 环境变量、`DeviceAllow` 全量（6 条）原样移植。**不装 `ollama` 元包**：它硬依赖 `ollama-rocm`，会拖进约 5.9 GB AMD ROCm 库。Fedora 无法打包 CUDA，GPU 后端改为 Vulkan（drop-in 里 `OLLAMA_VULKAN=1`）。另加 `StateDirectory=ollama`——ostree 不部署 `/var`，否则 `bootc switch` 后服务无家目录、无限重启。`loadModels` 变为 `ujust atomic-ws-ollama-pull` |
| `users.nix` | ujust：`atomic-ws-set-shell-fish`、`atomic-ws-sudo-nopasswd` | 用户/密码是安装期机器状态；fish 与免密 sudo 做成 opt-in 命令 |
| `nix.nix` / `nix-ld.nix` | — | 无 Nix；CLI 生态整体迁到 Homebrew |
| `desktop-niri.nix` | build.sh：dnf niri + strata（release tarball）+ `system_files` 的 niri drop-in 与 portal 配置 | niri 25.11 在 Fedora 44 仓库；strata 1.1.1 按其 tarball 手工放置（FileManager1 D-Bus + FileChooser portal），`FileChooser=strata;gtk` 原样 |
| `desktop-mango.nix` | 仅 chezmoi：`dot_config/mango/*.conf` | mango（mangowm）无 Fedora 包、无 release 二进制（Nix 独占构建）；配置保留备用，会话不可用 |
| `xdg.nix`（terminal-exec=ghostty、gvfs、portal） | `xdg-terminal-exec`（dnf）；ghostty 由 `install-user-apps.sh` 提供 | gvfs 走 dnf；portal 配置在 `system_files/etc/xdg-desktop-portal/niri-portals.conf`（portal 只读 `$XDG_CONFIG_DIRS*/xdg-desktop-portal/` 与 `/etc/xdg-desktop-portal/`，`/etc/xdg/portal/` 不会被读） |
| `magisk.nix`（只读 /etc overlay、machine-id） | — | bootc 天生镜像化 /etc，等价语义已存在 |
| `linuxqq-wayland-fix.nix` | — | 修补的是原生 QQ 包；atomic 上 QQ 走 flathub（自带同等修复），见 apps 清单 |
| `plymouth.nix`（mac-style 主题） | — | Bazzite 接管 plymouth；换主题需重建 initramfs，不合每日构建模式 |
| `packages.nix`（curl/wget） | — | 基础镜像已有 |

## home/（home-manager）模块

| main 模块 | atomic 落点 |
|---|---|
| `core.nix`（EDITOR=hx、polkit-gnome、mime inode/directory→strata） | `dot_config/environment.d/60-atomic-workstation.conf`（另含 brew PATH）；polkit 复用 Bazzite 的 KDE agent（`/usr/libexec/kf6/polkit-kde-authentication-agent-1`，niri `spawn-at-startup` 两路径探测）；mime 由 `run_once_10-xdg-and-units.sh` 设置，`doctor.sh` 复查 |
| `programs/fish.nix`（vi 键位、别名、jjmsg） | `dot_config/fish/config.fish` + `dot_config/fish/functions/jjmsg.fish`（jjmsg 逐字节移植） |
| `programs/git.nix` | `dot_config/git/config.tmpl` |
| `programs/jujutsu.nix` | `dot_config/jj/config.toml.tmpl`（difft/delta/SSH 签名原样）；`merge-editor = "meld"` 由 `dot_local/bin/executable_meld` 包装 flathub 的 `org.gnome.meld`（flatpak 不会把 `meld` 放进 PATH） |
| `programs/ssh.nix` | `private_dot_ssh/config` |
| `programs/ghostty.nix` | `dot_config/ghostty/config`（ghostty 本体来自 `install-user-apps.sh`） |
| `programs/direnv.nix` / `zoxide.nix` | brew 安装 + fish 配置里的 guarded init（`--cmd cd` 保留） |
| `programs/hourly-chime.nix` | `dot_config/systemd/user/hourly-chime.{service,timer}` + `dot_local/bin/executable_hourly-chime` |
| `programs/magpie.nix`（自启） | `dot_config/autostart/magpie.desktop`；本体 `install-user-apps.sh` |
| `programs/pig.nix`（Pi settings 合并） | 未移植：pig 已移除，`pi` 改用 brew 的 `pi-coding-agent`（自带 `pi` 命令）；Nix wrapper 的 `PIG_USE_PI_DIRS=1` 已不需要，`pi` 直接使用 `~/.pi/agent/`。`PI_SKIP_VERSION_CHECK=1` 需要时自行在 `dot_config/environment.d/60-atomic-workstation.conf` 里补 |
| `programs/gram.nix` | —（缺口）Gram 是 Zed 私有构建，无 Linux 分发 |
| `audio/rnnoise.nix` | `dot_config/pipewire/pipewire.conf.d/99-autogain.conf`：dyson 压缩器可用；rnnoise LADSPA 插件 Fedora 未打包（werman 插件不进仓库），节点注释保留，替代方案 EasyEffects。**控制端口名已按插件实际端口改正**（`Peak limit (dB)`/`Release time (s)`/`Fast compression ratio`/`Compression ratio`）——main 分支写的 `Input Gain`/`Threshold`/`Ratio`/`Attack Time`/`Makeup Gain` 在 dyson 里不存在，PipeWire 会逐条丢弃；模块另加 `flags = [ ifexists nofail ]`，镜像切换前缺插件也不至于把 PipeWire 拖死 |
| `desktop/niri/`（conf/*.kdl + reorder-workspaces.sh） | `dot_config/niri/` 原样移植；spawn-at-startup 增补 polkit agent；reorder 脚本 hostname 同时匹配 `nixos|bazzite` |
| `desktop/noctalia/` | `dot_config/noctalia/`（config.toml + gtk/fcitx5 模板原样） |
| `desktop/mango/` | `dot_config/mango/`（原样，见上） |
| `desktop/screenshot.nix` / `screenshot.sh` | `dot_local/bin/executable_screenshot`（satty 无 x86_64 Fedora 包 → swappy 等价移植）+ `executable_kbd-backlight` |
| `secrets.nix`（sops-nix） | — 私密数据不入镜像；机器上已就位（`~/.ssh`、`~/.pi`），备份走 `scripts/backup.sh` |

## home/packages（软件包）

| main 列表 | 去向 |
|---|---|
| `cli.nix`：neovim helix ripgrep fzf jq just gh jjui fd eza bat fastfetch dig shellcheck sops age ssh-to-age libxml2 file sing-box lody-pi | `apps/profiles/base.Brewfile`（其余走 brew）；`fzf jq fastfetch` 由 Bazzite 基础镜像提供，`dig/libxml2/file/just` 由镜像层（dnf）提供，均不再写进 Brewfile；ssh-to-age 无 brew 公式（需要时 `go install github.com/Mic92/ssh-to-age/cmd/ssh-to-age@latest`）；lody-pi 不需要（Lody 桌面自带运行时） |
| `dev.nix`：zig koka go mygo python3 nodejs jdt-language-server openjdk17 ast-grep typos opengrep binutils llvm jadx apktool erofs-utils android-tools payload-dumper-go r8 | brew（zig koka go node jdtls openjdk + openjdk@17 ast-grep typos-cli jadx apktool erofs-utils payload-dumper-go）；python3/binutils/llvm 走镜像或 distrobox；`android-tools` 在 `build_files/build.sh`（adb/fastboot）；mygo opengrep r8 → `install-user-apps.sh`（r8 装成 `r8`/`d8` 两个 wrapper，JDK 取 brew 的 keg-only `opt/openjdk@17`） |
| `dev.nix`（Nix 独占）：nix-init nixfmt nil nixd | —（无 Nix；需要时用 NixOS distrobox 容器，见 `containers/distrobox.ini`） |
| `gui.nix`：ddcutil wlsunset wl-clipboard tmux xwayland-satellite | 镜像（dnf）；ddcutil 例外——基础镜像自带 terra-ddcutil（同源 fork，提供 ddcutil 二进制），再装会冲突 |
| `gui.nix`：ungoogled-chromium wechat-uos obs-studio | flathub：`io.github.ungoogled_software.ungoogled_chromium` `com.tencent.WeChat` `com.obsproject.Studio`（base.flatpak.txt） |
| `gui.nix`：strata kero | 镜像（release tarball，build.sh） |
| `gui.nix`：magpie lody-mygo grok-bot folia-major ayugram-desktop | magpie → `install-user-apps.sh`；lody-mygo 仅发布 macOS dmg；grok-bot/folia-major/ayugram 无 Linux 分发（缺口） |
| `archive.nix`：zip unzip p7zip xz ffmpeg imagemagick poppler | 镜像层（dnf `zip/unzip/7zip/xz/ffmpeg/ImageMagick/poppler-utils`）；brew 不再重复安装 |
| `pkgs/` overlay：pig rtk sing-box | pig 已移除（`pi` 用 brew 的 `pi-coding-agent`）；rtk、sing-box → brew core |

## 本机现状（2026-11 采集）

* 会话：自定义镜像 `ghcr.io/lynimbus/atomic-workstation:latest`
  已 `bootc switch` 并重启（基础镜像 `bazzite-nvidia-open:stable`）；
  niri 会话已验证可启动（`niri validate` 通过、`/usr/share/wayland-sessions/
  niri.desktop` 存在），KDE Plasma 仍作为回退会话保留
* flatpak 应用（QQ、Firefox、OBS、KDE 系工具等）→ capture 后落在
  `apps/flatpak/inventory/bazzite.json`。**flathub 的 “Fcitx 5” 应用不进
  seed，也不进 inventory**：`apps/flatpak/inventory.py` 遇到它会跳过并打印
  卸载命令，因为 `restore.sh` 会照着 inventory 装机，把重复的输入法装到新机器
  上就是 bug。原因：镜像自带宿主 fcitx5，flathub 那个是给没装输入法的系统用的
  独立守护进程，两者会抢 fcitx5 的 D-Bus 名，rime 词库也会被隔到
  `~/.var/app/<app-id>` 里。
  **已完成**：镜像部署 + `install-user-apps.sh rime-ice` 之后
  （`~/.local/share/fcitx5/rime` 已有 rime-ice 词库、宿主 fcitx5 已接管
  `org.fcitx.Fcitx5` D-Bus 名），按 doctor 提示卸掉了该 flatpak
  （`flatpak uninstall --system org.fcitx.Fcitx5`，
  `scripts/doctor.sh` 用应用显示名匹配，不依赖 flathub 的 app id）
* brew：helix/jj/jjui/go/node/pi-coding-agent 等 → `apps/brew/inventory/bazzite/`
  （fish 与 jq 已从 brew 移除：`/usr/bin/fish`、`/usr/bin/jq` 由镜像提供，
  brew 版本排在 PATH 后面永远不会被解析到）
* `~/.local/bin/magpie`（自更新中，0.1.2909）、ghostty/opengrep/r8/mygo
  （`scripts/install-user-apps.sh` 安装）、Lody 桌面 AppImage

### 已知缺口：基础镜像由 bazzite-dx-nvidia 换成了 bazzite-nvidia-open

`bootc status` 的回滚项（上一份部署）是 `ghcr.io/ublue-os/bazzite-dx-nvidia:stable`，
当前自建镜像以 `bazzite-nvidia-open:stable` 为基础。DX 变体自带一批开发工具
（VS Code / `code`、docker、kubectl 等），普通 nvidia-open 变体没有，因此
`apps/brew/inventory/bazzite/Brewfile` 里的 vscode 扩展行在换基后消失
（`code` 不再存在）。GHCR 上没有 `bazzite-dx-nvidia-open` 变体（只有
`bazzite-dx-nvidia`），所以两者不可兼得：

* 若要保留 DX 的桌面开发体验，把 `image-template.env` 的 `BASE_IMAGE` 改回
  `ghcr.io/ublue-os/bazzite-dx-nvidia:stable` 并重建镜像；
* 若要 nvidia-open 驱动，则用 brew/flatpak 自行补上缺失的 CLI/GUI 工具
  （`code` 可用 flatpak `com.visualstudio.code`，或 brew `--cask` 不可用时的
  其它途径）。

这是一个待定的取舍，本分支目前选择 nvidia-open。

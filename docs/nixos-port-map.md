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
| `hardware.nix` | `system_files/etc/systemd/system/mnt-{windows,data}.*` | NTFS 挂载按同样的 UUID/参数移植为 systemd 挂载单元；`/mnt/data` 额外加 `nofail` 防止缺盘卡启动。zram/蓝牙/tuned 已是 Bazzite 默认（tuned 在镜像里显式 enable） |
| `ollama.nix` | build.sh：dnf ollama + `system_files/.../ollama.service.d/10-lynimbus.conf` | 环境/DeviceAllow 原样移植；vulkan 构建不可得（Fedora 包无该后端，NVIDIA 走 CUDA）。`loadModels` 变为 `ujust atomic-ws-ollama-pull` |
| `users.nix` | ujust：`atomic-ws-set-shell-fish`、`atomic-ws-sudo-nopasswd` | 用户/密码是安装期机器状态；fish 与免密 sudo 做成 opt-in 命令 |
| `nix.nix` / `nix-ld.nix` | — | 无 Nix；CLI 生态整体迁到 Homebrew |
| `desktop-niri.nix` | build.sh：dnf niri + strata（release tarball）+ `system_files` 的 niri drop-in 与 portal 配置 | niri 25.11 在 Fedora 44 仓库；strata 1.1.1 按其 tarball 手工放置（FileManager1 D-Bus + FileChooser portal），`FileChooser=strata;gtk` 原样 |
| `desktop-mango.nix` | 仅 chezmoi：`dot_config/mango/*.conf` | mango（mangowm）无 Fedora 包、无 release 二进制（Nix 独占构建）；配置保留备用，会话不可用 |
| `xdg.nix`（terminal-exec=ghostty、gvfs、portal） | `xdg-terminal-exec`（dnf）；ghostty 由 `install-user-apps.sh` 提供 | gvfs 走 dnf；portal 配置在 `system_files/etc/xdg/portal/niri-portals.conf` |
| `magisk.nix`（只读 /etc overlay、machine-id） | — | bootc 天生镜像化 /etc，等价语义已存在 |
| `linuxqq-wayland-fix.nix` | — | 修补的是原生 QQ 包；atomic 上 QQ 走 flathub（自带同等修复），见 apps 清单 |
| `plymouth.nix`（mac-style 主题） | — | Bazzite 接管 plymouth；换主题需重建 initramfs，不合每日构建模式 |
| `packages.nix`（curl/wget） | — | 基础镜像已有 |

## home/（home-manager）模块

| main 模块 | atomic 落点 |
|---|---|
| `core.nix`（EDITOR=hx、polkit-gnome、mime inode/directory→strata） | `dot_config/environment.d/60-atomic-workstation.conf`；polkit 复用 Bazzite 的 KDE agent（niri `spawn-at-startup`）；mime 由 `run_once_10-xdg-and-units.sh` 设置 |
| `programs/fish.nix`（vi 键位、别名、jjmsg） | `dot_config/fish/config.fish` + `dot_config/fish/functions/jjmsg.fish`（jjmsg 逐字节移植） |
| `programs/git.nix` | `dot_config/git/config.tmpl` |
| `programs/jujutsu.nix` | `dot_config/jj/config.toml.tmpl`（difft/delta/meld/SSH 签名原样；工具来自 brew/flatpak） |
| `programs/ssh.nix` | `private_dot_ssh/config` |
| `programs/ghostty.nix` | `dot_config/ghostty/config`（ghostty 本体来自 `install-user-apps.sh`） |
| `programs/direnv.nix` / `zoxide.nix` | brew 安装 + fish 配置里的 guarded init（`--cmd cd` 保留） |
| `programs/hourly-chime.nix` | `dot_config/systemd/user/hourly-chime.{service,timer}` + `dot_local/bin/executable_hourly-chime` |
| `programs/magpie.nix`（自启） | `dot_config/autostart/magpie.desktop`；本体 `install-user-apps.sh` |
| `programs/pig.nix`（Pi settings 合并） | 机器现状保留：`~/.pi/agent/` 已存在，PiG 指向它（pig 由 `install-user-apps.sh` 提供） |
| `programs/gram.nix` | —（缺口）Gram 是 Zed 私有构建，无 Linux 分发 |
| `audio/rnnoise.nix` | `dot_config/pipewire/pipewire.conf.d/99-autogain.conf`：dyson 压缩器可用；rnnoise LADSPA 插件 Fedora 未打包（werman 插件不进仓库），节点注释保留，替代方案 EasyEffects |
| `desktop/niri/`（conf/*.kdl + reorder-workspaces.sh） | `dot_config/niri/` 原样移植；spawn-at-startup 增补 polkit agent；reorder 脚本 hostname 同时匹配 `nixos|bazzite` |
| `desktop/noctalia/` | `dot_config/noctalia/`（config.toml + gtk/fcitx5 模板原样） |
| `desktop/mango/` | `dot_config/mango/`（原样，见上） |
| `desktop/screenshot.nix` / `screenshot.sh` | `dot_local/bin/executable_screenshot`（satty 无 x86_64 Fedora 包 → swappy 等价移植）+ `executable_kbd-backlight` |
| `secrets.nix`（sops-nix） | — 私密数据不入镜像；机器上已就位（`~/.ssh`、`~/.pi`），备份走 `scripts/backup.sh` |

## home/packages（软件包）

| main 列表 | 去向 |
|---|---|
| `cli.nix`：neovim helix ripgrep fzf jq just gh jjui fd eza bat fastfetch dig shellcheck sops age ssh-to-age libxml2 file sing-box lody-pi | `apps/profiles/base.Brewfile`（brew 均有，除下述）；dig/libxml2/file/just 已在镜像（dnf）；ssh-to-age 无 brew 公式（需要时 `go install github.com/Mic92/ssh-to-age/cmd/ssh-to-age@latest`）；lody-pi 不需要（Lody 桌面自带运行时） |
| `dev.nix`：zig koka go mygo python3 nodejs jdt-language-server openjdk17 ast-grep typos opengrep binutils llvm jadx apktool erofs-utils android-tools payload-dumper-go r8 | brew（zig koka go node jdtls openjdk@17 ast-grep typos-cli jadx apktool erofs-utils payload-dumper-go）；python3/android-tools/binutils/llvm 走镜像或 distrobox；mygo opengrep r8 → `install-user-apps.sh` |
| `dev.nix`（Nix 独占）：nix-init nixfmt nil nixd | —（无 Nix；需要时用 NixOS distrobox 容器，见 `containers/distrobox.ini`） |
| `gui.nix`：ddcutil wlsunset wl-clipboard tmux xwayland-satellite | 镜像（dnf）；ddcutil 例外——基础镜像自带 terra-ddcutil（同源 fork，提供 ddcutil 二进制），再装会冲突 |
| `gui.nix`：ungoogled-chromium wechat-uos obs-studio | flathub：`io.github.ungoogled_software.ungoogled_chromium` `com.tencent.WeChat` `com.obsproject.Studio`（base.flatpak.txt） |
| `gui.nix`：strata kero | 镜像（release tarball，build.sh） |
| `gui.nix`：magpie lody-mygo grok-bot folia-major ayugram-desktop | magpie → `install-user-apps.sh`；lody-mygo 仅发布 macOS dmg；grok-bot/folia-major/ayugram 无 Linux 分发（缺口） |
| `archive.nix`：zip unzip p7zip xz ffmpeg imagemagick poppler | 镜像（dnf 7zip/xz/ffmpeg/imagemagick/poppler）+ brew 兜底 |
| `pkgs/` overlay：pig rtk sing-box | pig → `install-user-apps.sh`；rtk、sing-box → brew core |

## 本机现状（2026-11 采集）

* 会话：KDE Plasma（Bazzite DX 镜像）；待部署 `bazzite-nvidia-open:testing`
* flatpak 14 个应用（QQ、Firefox、Fcitx5+Rime、OBS 插件、KDE 系工具等）→ 首次
  capture 后落在 `apps/flatpak/inventory/bazzite.json`
* brew：fish/helix/jj/jjui/go/node/pi-coding-agent 等 → `apps/brew/inventory/bazzite/`
* `~/.local/bin/magpie`（自更新中，0.1.2909）、Lody 桌面 AppImage

<div align="center">

# ❄️ lynimbus's NixOS Flake

**面向 Wayland 桌面、AI 编码智能体与现代工具链的声明式 NixOS 配置**

[![NixOS Unstable](https://img.shields.io/badge/NixOS-unstable-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![Kernel](https://img.shields.io/badge/Kernel-CachyOS_LTO_Zen4-00A8E8?style=flat-square&logo=linux&logoColor=white)](https://github.com/xddxdd/nix-cachyos-kernel)
[![Shell](https://img.shields.io/badge/Desktop-Noctalia_%2B_Umbriel_%2F_Mango-8A2BE2?style=flat-square)](https://github.com/noctalia-dev/noctalia)
[![VCS](https://img.shields.io/badge/VCS-Jujutsu_(jj)-F05032?style=flat-square&logo=git&logoColor=white)](https://github.com/jj-vcs/jj)

</div>

---

一套追求**极简、自洽与零冗余**的个人 NixOS 与 Home Manager 配置（主机名 `nixos`，针对 Mechrevo GM5HG0A / AMD Zen 4 笔记本深度调优）。仓库内置 **22 个本地自维护软件包**、**双模式 Wayland 合成器环境**、**端侧 Vulkan AI 翻译流水线**以及**完整的多智能体（Multi-Agent）编码工具栈**。

## ✨ 核心亮点

- **🌌 Noctalia Wayland 桌面生态**
  - **双合成器随时切换**：默认搭载滚动式平铺合成器 **[Umbriel](https://github.com/noctalia-dev/umbriel)**（Scrollable tiling），同时配备动态平铺合成器 **[Mango](https://github.com/mangowm/mango)**（Dwindle tiling）。
  - **全家桶级视觉统一**：集成 **[Noctalia](https://github.com/noctalia-dev/noctalia)** 桌面 Shell、**Noctalia Greeter** 登录管理器与 **[Luciole](https://github.com/noctalia-dev/luciole)** 原生文件管理器，支持配色与 Fcitx5 / GTK3 主题联动。
  - **热编辑配置（`liveFiles`）**：通过 `home/init.nix` 注入 `_module.args.liveFiles`，将窗口管理器、快捷键与 Rime 输入法词库以 `mkOutOfStoreSymlink` 链接至仓库源码，修改即刻生效，无需触发 `nh os switch`。

- **🤖 本地优先的 AI 与 Agent 工具栈**
  - **多智能体协同与沙盒**：内置 `pi` / `pig`（单二进制 Go 移植版 Pi，无缝兼容 TS 扩展）、`pig-swarm`（基于 Beads 账本的多智能体并发编排）、`t3code`、`alma`、`antigravity-hub` / `antigravity-cli`、`herdr-core`、`kero`、`obelisk-cli`（历史会话 SQLite 检索）以及 `blackhole`（仅挂载当前工作目录的容器化 Claude Code）。
  - **Fcitx5 端侧实时中译英**：自研 C++ 插件 `fcitx5-hymt-translate` 搭配用户态 `hy-mt2-server` 服务（基于 `llama.cpp` Vulkan 后端运行 `tencent/Hy-MT2-1.8B-GGUF:Q8_0`），在输入法内按下快捷键即可异步完成中译英并直接上屏。
  - **夜间自动思想归纳（`memo`）**：随手通过 `memo` 记录灵感碎片，每晚由 systemd 定时器触发 `memo-digest`，通过本地模型网关 `magpie` 按主题自动聚类归档。

- **⚡ 内核、编译与安全自愈**
  - **Zen 4 LTO 内核与启动防砖**：采用 `nix-cachyos-kernel`（Clang + ThinLTO + `znver4` 优化，直连 Hydra 二进制缓存免编译）；启用 `systemd-boot` 启动计数（`bootCounting`），配合 `boot-complete-check.service` 确保 DRM 显卡设备与 `greetd` 登录界面真正就绪后才标记系统世代为健康，连续失败自动回滚。
  - **跨沙盒共享 `sccache` + `mold`**：在 `/var/cache/sccache` 维护 20G 编译缓存，通过 POSIX ACL 与 `extra-sandbox-paths` 同时供 Nix 沙盒内的 Crane Rust 构建与宿主机日常 `cargo` 调用，全链路默认使用 `mold` 链接器。
  - **Overlay `/etc` 密码防锁死守卫**：在 `system/password-guard.nix` 中实现纯 Shell 激活守卫，自动拦截 `hashedPasswordFile` 缺失或 `/etc/shadow` 异常锁死状态并从现有 shadow 自动回填，彻底规避可变 `/etc` overlay 重建时的账户锁死隐患。

- **🔍 自省式桌面概览应用（`overview`）**
  - 使用 MyGo（Go + GTK3/Cairo）编写的原生桌面应用 `pkgs/overview`，直接求值 `pkgs/overview/data.nix` 读取当前 Flake 的 NixOS 与 Home Manager 最终配置，可视化展示已安装应用、本机衍生包、终端配置与工具链版本，并在构建阶段运行无头 Pango/Cairo 布局回归测试。

---

## 🗂️ 仓库架构

```text
.
├── flake.nix                 # Flake 入口：inputs、共享 sccache、overlay 注入、nixosConfigurations 与 checks
├── overlay.nix               # 自动扫描 pkgs/*.nix，按函数签名按需注入 repoRoot / craneLib / buildMyGoApp
├── justfile                  # 日常构建、测试、格式化、自动追新与脚手架任务入口
├── lib/
│   ├── build-mygo-app.nix    # MyGo (Go + GTK3) 原生桌面应用通用构建器与运行库包装器
│   └── fonts.nix             # 系统与用户态共享字体配置
├── pkgs/                     # 22 个本地维护软件包与树内源码
│   ├── overview/             # 原生 NixOS Flake 配置概览桌面应用 (Go + GTK3 + i18n)
│   ├── fcitx5-hymt-translate/# Fcitx5 异步本地大模型中英翻译 C++ 插件
│   └── *.nix                 # 各类 Agent 工具、GUI 应用与 Android 逆向/构建工具链
├── system/                   # NixOS 系统级模块 (经由 system/init.nix 统一聚合)
│   ├── boot.nix              # CachyOS LTO Zen4 内核、Plymouth 动画与 systemd-boot 启动计数
│   ├── boot-complete.nix     # DRM 显卡 + greetd 存活校验，守护启动回滚闭环
│   ├── nix.nix               # 镜像源、二进制缓存、构建调度优先级与跨沙盒 sccache 挂载
│   ├── password-guard.nix    # 激活期 shadow 密码哈希自愈守卫
│   ├── desktop.nix           # Umbriel / Mango / Noctalia / Greeter 与 LinuxQQ Wayland 修复
│   ├── audio.nix             # PipeWire 低延迟音频栈
│   ├── gaming.nix            # Steam、Gamescope、Gamemode 与 Proton-GE
│   └── ...                   # 网络、sing-box、Docker、Wireshark、Comma (nix-index) 等
├── home/                     # Home Manager 用户级模块 (经由 home/init.nix 统一聚合)
│   ├── desktop/              # Umbriel、Mango、Noctalia、Luciole、Fcitx5 (Rime 雾凇拼音)
│   ├── programs/             # Ghostty、Fish、Jujutsu、Git、Yazi、Memo、Hy-MT2、Pig、Nsh、Rust 等
│   ├── audio/rnnoise.nix     # PipeWire LADSPA 自动增益 (dysonCompress) + RNNoise 麦克风降噪链
│   └── packages.nix          # CLI、桌面应用、多语言工具链与 Android 逆向套件清单
└── scripts/                  # 自动化维护脚本
    ├── bump-packages.sh      # 读取 legacyPackages.bumpMatrix 并发更新所有声明了 passthru.bump 的包
    ├── scaffold-package.sh   # 调用 nix-init 生成符合本仓库规范的 pkgs/<name>.nix
    └── lib.sh                # 共享终端输出与 GitHub Token 注入辅助函数
```

---

## 📦 本地软件包矩阵（`pkgs/`）

`overlay.nix` 会自动发现 `pkgs/` 下的所有 `.nix` 文件，同时导出至 `packages.x86_64-linux.<name>`（支持 `nix build .#<pkg>` 单独构建）与 `legacyPackages.x86_64-linux.bumpMatrix`（驱动 `just bump` 自动追新）。

| 类别 | 包名 | 说明 |
| :--- | :--- | :--- |
| **系统与输入法** | `overview` | 原生 MyGo 桌面应用，实时自省并可视化展示本 Flake 安装的包与模块设置 |
| | `fcitx5-hymt-translate` | Fcitx5 C++ 插件，通过本地 `Hy-MT2-1.8B` (`llama.cpp`) 实现异步中译英 |
| | `sing-box` | 通用代理平台（跟进上游 prerelease 二进制并补齐 NixOS systemd/polkit 资产） |
| **AI 编码与 Agent** | `pig` | 用 Go 重构为单原生二进制的 Pi 智能体，原样运行 Pi 的 TypeScript 扩展 |
| | `pig-swarm` | 将多个 `pig` 智能体围绕同一问题并发扇出，以 `bd` (Beads) epic 作为账本 |
| | `t3code` | 极简编码智能体 Web GUI（含原生资源诊断 sidecar） |
| | `alma` | 支持 `herdr`、Claude Code、Codex 与 `pi` 的 Agent 客户端与 Harness |
| | `antigravity-cli` | Google Antigravity 终端智能体客户端 |
| | `antigravity-hub` | 跨独立项目管理多个自主智能体的桌面环境 |
| | `blackhole` | 在仅挂载当前项目目录的 Linux 容器中隔离运行 Claude Code |
| | `herdr-core` | 脱离窗口后会话依然存活的编码智能体终端 (`hc`) |
| | `kero` | 会话生命周期独立于窗口的原生编码智能体终端 |
| | `obelisk-cli` | 将过往编码智能体会话索引至本地 SQLite 数据库，供 Agent 检索回溯 |
| | `rtk` | CLI 代理，在常见开发命令输出送达 LLM 前自动裁剪冗余上下文 |
| **编辑器与桌面应用** | `mayoi` | 基于 GPU 自绘 UI 的代码编辑器，支持标签页、分屏、插件与 Vim 模式 |
| | `mygo-music` | 支持本地曲库与流媒体账号登录的原生音乐播放器 |
| **开发与 Android 工具链** | `mygo` | 脚手架、开发与打包 MyGo 桌面应用的 CLI 工具 |
| | `nsh` / `nsh-android-sdk` | Native Shell（TSX 原生运行时 GUI 框架）及其配套 Android SDK 组合 |
| | `r8` | 来自 Google Maven 的 Android dex 编译器 (`d8`) 与代码压缩优化器 (`r8`) |
| | `opengrep` | 开源静态代码分析引擎（无登录、无遥测的 Semgrep 分支） |
| | `dolt` | 支持 Git 风格版本控制的 SQL 数据库（支撑 Beads 本地问题追踪） |

---

## 🛠️ 常用操作与工作流

日常管理全部封装在 [`justfile`](./justfile) 中，底层通过 [`nh`](https://github.com/nix-community/nh) 提供清晰的构建进度与世代差异对比（`nvd`）：

### 系统构建与切换

```bash
just switch          # 构建并立即激活新的 NixOS 与 Home Manager 世代 (nh os switch .)
just try             # 立即激活新配置但不写入引导默认项，重启即可恢复 (nh os test .)
just stage           # 仅将新世代设为下次启动默认项，当前会话不切换 (nh os boot .)
just build           # 仅编译完整系统配置，不激活 (nh os build .)
just gens            # 列出所有可回滚的历史系统世代
just undo            # 一键回滚至上一个系统世代 (nh os rollback)
just gc              # 清理 3 天前的历史世代并执行 nix store 硬链接去重优化
```

### 包管理与自动化追新

每个需要跟随上游发布的包只需在自身 `pkgs/<name>.nix` 中声明 `passthru.bump = [ ... ];`（传给 `nix-update` 的参数），无需修改任何脚本：

```bash
just update                        # 自动注入 gh token 并更新 flake.lock 所有输入
just bump                          # 批量更新 pkgs/ 下所有声明了 passthru.bump 的本地包
just bump pig kero                 # 仅更新指定的本地包
just scaffold <github-url> [ver]   # 使用 nix-init 自动生成符合本仓库规范的 pkgs/<name>.nix
just snapshot                      # 重新求值 pkgs/overview/data.nix 并刷新 overview 内置快照
```

### 质量门禁与校验

本仓库将规范直接编码进 `flake.nix` 的 `checks.x86_64-linux` 中：

```bash
just fmt             # 使用 nixfmt-tree 格式化全仓 Nix 代码
just check           # 运行全部 Flake 检查：
                     #   1. formatting     — nixfmt 格式检查
                     #   2. shellcheck     — scripts / pkgs / home 下所有 Shell 脚本静态检查
                     #   3. pkg-invariants — 校验所有本地包的 pname、meta.description、meta.position 与 bump 规则
                     #   4. overview       — 编译 overview 并运行 GTK/Pango 无头 UI 布局测试与 installCheck
just memo-verify     # 端到端测试 memo 的记录、聚类摘要与检索（含失败路径覆盖）
```

---

## 🧭 设计哲学

1. **单一事实来源（Single Source of Truth）**
   - `nixpkgsConfig`、Overlays、`sccache` 参数与模块参数 `moduleArgs` 均在 [`flake.nix`](./flake.nix) 顶层一次性定义，同时分发给 `packages`、`legacyPackages`、NixOS 模块与 Home Manager，避免多处维护。
   - [`pkgs/overview/data.nix`](./pkgs/overview/data.nix) 直接从求值后的 `nixosConfigurations.nixos` 推导所有应用分类、图标路径与程序设置，新增软件包无需手动同步文档列表。
2. **契约化的本地包自发现**
   - 往 [`pkgs/`](./pkgs) 放入一个 `.nix` 文件即可被 [`overlay.nix`](./overlay.nix) 自动注册；同时由 `pkg-invariants` 检查强制保证每个包具备完善的 `pname`、`meta.description` 以及正确的 `nix-update` 源码位置。
3. **配置极简化（Configuration Minimalism）**
   - 绝不重复声明上游模块已处理的默认值、环境变量或包装脚本；需要高频调优的桌面配置（如窗口管理器与输入法配置）通过 `liveFiles` 保持工作树直连，兼顾 Nix 的可复现性与日常微调的即时反馈。

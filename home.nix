{ config, pkgs, ... }:

{
  home.username = "lynimbus";
  home.homeDirectory = "/home/lynimbus";
  home.stateVersion = "26.05";

  # ==========================================================================
  # 软件管理统一为声明式（2026-08-07 迁移）
  #
  # 之前用 `nix profile` 命令式安装，无法回滚/复现（flake.lock 不锁定）。
  # 现已全部迁入 home.packages：
  #   - 版本由 flake.lock 锁定，`home-manager switch` 一次部署、可回滚
  #   - 增删软件 = 改这个文件 + switch，不再需要 `nix profile install/remove`
  #   - `nix profile` 已清空，仅作为临时实验手段
  #
  # 决策矩阵（详见 AGENTS.md）：
  #   - 用户级 CLI/桌面应用 → home.packages（本文件）
  #   - 系统组件/登录 shell/字体/服务/深度集成 GUI → pacman
  #   - 临时工具 → `nix shell nixpkgs#<pkg>`
  #
  # 2026-08-11 结构优化：dotfiles 拆分到 modules/ 由 HM 模块声明式托管。
  #   - git  / jujutsu → modules/vcs.nix      （programs.git / programs.jujutsu）
  #   - zed / neovim   → modules/editors.nix  （programs.zed-editor）
  #   - ghostty        → modules/terminal.nix （programs.ghostty）
  #   - fish           → 仍由 home.file 托管（登录 shell 必须留在 /usr/bin，
  #                     programs.fish 模块会强装 Nix 版 fish 造成 PATH 双份，
  #                     故手写 config.fish，内容见 config/fish/config.fish）
  # ==========================================================================
  home.packages = [
    # --- shell 增强 ---
    pkgs.delta        # git diff 高亮（git 模块里配作 pager）
    pkgs.eza          # ls 替代
    pkgs.fd           # find 替代
    pkgs.fzf          # 模糊查找
    pkgs.starship     # 提示符
    pkgs.zoxide       # cd 记忆
    pkgs.bat          # cat 替代

    # --- 文件 / 系统信息 ---
    pkgs.yazi         # 终端文件管理器
    pkgs.moreutils    # sponge 等实用工具
    pkgs.fastfetch    # 系统信息
    pkgs.hyfetch      # fastfetch 主题
    pkgs.macchina     # 系统信息（备选）

    # --- 编辑器 ---
    pkgs.neovim       # nvim（EDITOR 指向它）
    # zed 已迁回 pacman（extra/zed）：Nix 版与系统 GL 栈不兼容，见 AGENTS.md

    # --- 版本控制 ---
    pkgs.jjui         # jj TUI（jujutsu 本体由 modules/vcs.nix 的 programs.jujutsu 管理）

    # --- 工具 ---
    pkgs.yq-go        # YAML/JSON 处理
    pkgs.just         # 命令运行器（`just` 即可更新/部署，见仓库根目录 justfile）
  ];
  # 注意：
  # - nodejs 由 pacman 管理（26.6.0，被 pi-coding-agent-git 依赖），
  #   不要在 Nix 侧重复安装，避免 PATH 上出现两个 node。
  # - fish / git 本体由 pacman 管理，Nix 侧不重复装（避免 PATH 双份/版本漂移）。

  # 只读托管文件。其余配置分散在 modules/*.nix 中。
  home.file = {
    # fish shell（登录 shell 仍是 /usr/bin/fish，这里是交互配置）
    ".config/fish/config.fish".source = ./config/fish/config.fish;
  };

  imports = [
    ./modules/vcs.nix
    ./modules/editors.nix
    ./modules/terminal.nix
  ];

  # home-manager 自身：enable 后命令自动进入 PATH（package 为只读选项，勿手动设置）
  programs.home-manager.enable = true;
}

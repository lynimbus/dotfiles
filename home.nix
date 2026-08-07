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
  # ==========================================================================
  home.packages = [
    # --- shell 增强 ---
    pkgs.bat          # cat 替代
    pkgs.delta        # git diff 高亮
    pkgs.eza          # ls 替代
    pkgs.fd           # find 替代
    pkgs.fzf          # 模糊查找
    pkgs.starship     # 提示符
    pkgs.zoxide       # cd 记忆

    # --- 文件 / 系统信息 ---
    pkgs.yazi         # 终端文件管理器
    pkgs.moreutils    # sponge 等实用工具
    pkgs.fastfetch    # 系统信息
    pkgs.hyfetch      # fastfetch 主题
    pkgs.macchina     # 系统信息（备选）

    # --- 编辑器 ---
    pkgs.neovim       # nvim（EDITOR 指向它）
    pkgs.zed-editor   # GUI 编辑器（Nix 版工作正常；若出现 glibc/GL 兼容问题，
                      #   参照 ghostty 教训迁回 pacman）

    # --- 版本控制 ---
    pkgs.jujutsu      # jj
    pkgs.jjui         # jj TUI

    # --- 工具 ---
    pkgs.yq-go        # YAML/JSON 处理
  ];
  # 注意：nodejs 由 pacman 管理（26.6.0，被 pi-coding-agent-git 依赖），
  # 不要在 Nix 侧重复安装，避免 PATH 上出现两个 node。

  # 这里只声明式托管 dotfiles 配置。
  home.file = {
    # fish shell（登录 shell 仍是 /usr/bin/fish，这里是交互配置）
    ".config/fish/config.fish".source = ./config/fish/config.fish;

    # Zed 编辑器
    ".config/zed/settings.json".source = ./config/zed/settings.json;

    # Ghostty 终端
    # （ghostty 由 pacman 管理：Nix 版 glibc 2.42 与系统 GL 栈要求的 2.43+ 不兼容，
    #   详见 2026-08-07 排障记录。此文件两种安装方式共用。）
    ".config/ghostty/config".source = ./config/ghostty/config;

    # git 全局 ignore
    ".config/git/ignore".source = ./config/git/ignore;
  };

  # home-manager 自身：enable 后命令自动进入 PATH（package 为只读选项，勿手动设置）
  programs.home-manager.enable = true;
}

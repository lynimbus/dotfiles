{ config, pkgs, ... }:

{
  home.username = "lynimbus";
  home.homeDirectory = "/home/lynimbus";
  home.stateVersion = "26.05";

  # 软件包由 `nix profile` 管理（见 `nix profile list`），
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

  # 让非登录 shell 也读 Nix 环境（保持默认即可，无需额外配置）
  programs.home-manager.enable = true;
}

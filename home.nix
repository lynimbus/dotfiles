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
    ".config/ghostty/config".source = ./config/ghostty/config;

    # Ghostty 启动包装器 + 桌面入口覆盖
    # （Nix 版 ghostty 的 glvnd 无法自动加载系统 EGL vendor，需注入环境变量）
    ".local/bin/ghostty".source = ./config/ghostty/launcher.sh;
    ".local/bin/ghostty".executable = true;
    ".local/share/applications/com.mitchellh.ghostty.desktop".source = ./config/ghostty/com.mitchellh.ghostty.desktop;

    # git 全局 ignore
    ".config/git/ignore".source = ./config/git/ignore;
  };

  # 让非登录 shell 也读 Nix 环境（保持默认即可，无需额外配置）
  programs.home-manager.enable = true;
}

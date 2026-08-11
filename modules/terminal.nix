{ config, lib, pkgs, ... }:

{
  # ==========================================================================
  # Ghostty 终端：本体由 pacman 管理（package = null 只托管配置）。
  #
  # 历史：2026-08-07 曾尝试迁移到 Nix，但 Nix 版 glibc(2.42) 与系统 GL 栈
  # 要求的 glibc(2.43+) 不兼容，EGL 渲染失败，故 ghostty 走 pacman（见 AGENTS.md）。
  #
  # 这里只声明行为一致的浅层默认：主题 One Dark（与 zed 一致）+ 窗口内边距。
  # 其他偏好（字体、字号、透明度等）按需在 settings 里加。
  # ==========================================================================
  programs.ghostty = {
    enable = true;
    package = null;
    systemd.enable = false;   # 无 Nix 版 ghostty 可托管 systemd 服务;pacman 版由系统管理

    settings = {
      theme = "Atom One Dark";   # 内置主题(与 zed 的 One Dark 观感一致)
      window-padding-x = 8;
      window-padding-y = 8;
      cursor-style = "block";
      font-family = "Iosevka Term";   # ttc-iosevka，Term 变体专为终端优化
      font-size = 12;
    };
  };
}

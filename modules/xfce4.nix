{ config, lib, pkgs, ... }:

# Xfce 组件（Thunar 生态）辅助配置
#
# 背景：Thunar 右键"Open Terminal Here"（在终端中打开）走
#   exo-open --launch TerminalEmulator → xfce4-mime-helper（xfce4-settings 包）
# 这套框架需要两样东西，缺了右键打开终端就会坏（无声无息失败）：
#   1. xfce4-mime-helper 本体 → pacman 安装 xfce4-settings（与 thunar/exo 同为 pacman 管理）
#   2. 终端模拟器的 helper 定义 + helpers.rc 默认值（本文件托管）
#
# mime-helper 查找机制（xfce4-settings 源码 xfce-mime-helper.c）：
#   - 默认值读 ~/.config/xfce4/helpers.rc 的 [Default] TerminalEmulator=<id>
#   - <id> 解析为 xfce4/helpers/<id>.desktop（XDG_DATA 路径，即 ~/.local/share 或 /usr/share）
#   - 该 desktop 文件须 Type=X-XFCE-Helper 并带 X-XFCE-* 命令键；
#     "在终端中打开" 传的是目录路径，走 X-XFCE-CommandsWithParameter（%s 替换为路径）
#
# ghostty 的 --working-directory=<dir> 正好匹配这一场景。
{
  home.file = {
    # ghostty helper 定义（mime-helper 按 ID 找这个文件）
    ".local/share/xfce4/helpers/com.mitchellh.ghostty.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Type=X-XFCE-Helper
      Icon=com.mitchellh.ghostty
      Name=Ghostty
      StartupNotify=false
      X-XFCE-Binaries=ghostty;
      X-XFCE-Category=TerminalEmulator
      # env TERM_PROGRAM=ghostty 是关键：ghostty 凭 TERM_PROGRAM 判断是否 CLI 环境。
      # 从桌面/文件管理器启动（如 thunar 右键）时无 TERM_PROGRAM，ghostty 会退回 $HOME
      # 而不是继承启动目录（ghostty Config.zig probableCliEnvironment）。
      X-XFCE-Commands=env TERM_PROGRAM=ghostty %B;
      X-XFCE-CommandsWithParameter=env TERM_PROGRAM=ghostty %B --working-directory=%s;
    '';

    # 默认终端模拟器 → ghostty helper
    ".config/xfce4/helpers.rc".text = ''
      [Default]
      TerminalEmulator=com.mitchellh.ghostty
    '';
  };
}

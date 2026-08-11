{ config, lib, pkgs, ... }:

{
  # ==========================================================================
  # Zed 编辑器：本体由 pacman 管理（package = null 只托管配置，见 AGENTS.md：
  # Nix 版与系统 GL 栈不兼容）。
  #
  # mutableUserSettings 默认开启：settings.json 是真实文件（不是 store 符号链接），
  # zed 内部可以自己改（如换主题），switch 时声明式设置合并回去覆盖同名键。
  # ==========================================================================
  programs.zed-editor = {
    enable = true;
    package = null;

    userSettings = {
      # 遥测全关
      telemetry = {
        diagnostics = false;
        metrics = false;
      };

      vim_mode = true;
      ui_font_size = 16;
      buffer_font_size = 16;

      theme = {
        mode = "dark";
        light = "One Light";
        dark = "One Dark";
      };

      remove_trailing_whitespace_on_save = false;   # 有意保留，勿动
      ensure_final_newline_on_save = true;
    };
  };
}

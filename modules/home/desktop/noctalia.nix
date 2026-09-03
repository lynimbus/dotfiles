{ ... }:

{
  # noctalia v5：Wayland shell（顶栏/启动器/锁屏/剪贴板），niri 配置大量引用。
  # 走 home-manager 自带模块，package 默认 pkgs.noctalia（nixpkgs 的 5.0.0-beta.9，
  # 与 Arch 上的 v5.0.0 同线、IPC 兼容）。启动仍由 niri 的 spawn-at-startup "noctalia"
  # 负责（与 Arch 上行为一致），所以不开 systemd 服务，避免双启动。
  # settings 接受 attrset / 原始 TOML 字符串 / .toml 文件路径：构建期经
  # `noctalia config validate` 校验后写入 ~/.config/noctalia/config.toml。
  # 配置内容移植自上游 NyxNiri（configs/noctalia/noctalia-config.toml），
  # 按本机裁剪（去掉 mpvpaper/echolyrics 插件与 fcitx5 模板注册等），
  # 文件头注释里列了所有改动点。注意运行时设置面板的改动会写进
  # ~/.local/state/noctalia/settings.toml 并覆盖这里的值，属预期行为。
  programs.noctalia = {
    enable = true;
    settings = ../../../home/config/noctalia/noctalia-config.toml;
  };

}

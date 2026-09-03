{ pkgs, inputs, ... }:

{
  # niri：niri-flake 模块 + liquid-glass 补丁包（glassOverlay 定义在 flake.nix）。
  # 启用后 SDDM 会出现 niri 会话；登录界面默认进 niri，Plasma 保留兜底。
  # 配置本体（programs.niri.config）在 home/flakeos.nix，构建期校验。
  programs.niri = {
    enable = true;
    package = pkgs.niri-glass;
  };

  services = {
    desktopManager.plasma6.enable = true;
    displayManager.sddm.enable = true;
    displayManager.sddm.wayland.enable = true;
    # 默认会话切到 niri-glass（KDE 的会话名是 plasma，这里两者都在 SDDM 列表里）
    displayManager.defaultSession = "niri";
  };

}

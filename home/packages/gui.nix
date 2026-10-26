{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ddcutil
    wlsunset
    wl-clipboard
    tmux
    xwayland-satellite
    ungoogled-chromium
    ayugram-desktop
    qq
    wechat-uos
    strata
    claude-desktop-zh
    deepseek-bot
    kero
    folia-major
    obs-studio
  ];
}

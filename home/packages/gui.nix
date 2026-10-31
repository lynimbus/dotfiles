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
    wechat-uos
    strata
    kero
    lody-mygo
    folia-major
    obs-studio
    grok-bot
  ];
}

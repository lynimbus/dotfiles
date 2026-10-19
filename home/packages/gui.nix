{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ddcutil
    wlsunset
    wl-clipboard
    tmux
    gvfs
    xwayland-satellite
    ungoogled-chromium
    ayugram-desktop
    qq
    wechat-uos
    strata
    claude-desktop-zh
    pi-agent-desktop
    folia-major
    obs-studio
  ];
}

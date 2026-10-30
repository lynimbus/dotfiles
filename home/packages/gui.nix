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
    folia-major
    obs-studio
  ];
}

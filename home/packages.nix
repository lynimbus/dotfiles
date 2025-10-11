{ pkgs, ... }:
{
  home.packages = with pkgs; [
    broot
    fastfetch
    hyfetch

    zip
    xz
    unzip
    p7zip

    ffmpeg
    jq
    poppler
    fd
    ripgrep
    fzf
    zoxide
    resvg
    imagemagick
    eza
    devenv
    devbox

    lazygit
    lazyjj
    jjui
    jj-fzf
    mergiraf
    delta

    vscode-fhs
    zed-editor-fhs
    telegram-desktop
    qq
    motrix
    obs-studio

    hmcl
    zulu
  ];
}

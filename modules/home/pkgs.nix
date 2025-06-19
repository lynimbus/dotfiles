{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    fastfetch
    neovim
    tmux
    docker
    tree

    file
    ffmpeg
    p7zip
    jq
    poppler
    fd
    ripgrep
    fzf
    zoxide
    resvg
    imagemagick
    xclip
    yazi
    # GUI
    firefox
    inputs.zen-browser.packages."${system}".default
    bilibili
    localsend
    qq
    wechat-uos
    telegram-desktop
    vscode

    hmcl
    jdk17

    obs-studio
  ];
}

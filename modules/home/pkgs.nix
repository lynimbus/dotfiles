{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    fastfetch
    neovim
    tmux
    docker
    tree
    # yazi
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
    localsend
    qq
    wechat-uos
    telegram-desktop
    code-cursor
    vscode

    hmcl
    jdk17

    obs-studio
  ];
}

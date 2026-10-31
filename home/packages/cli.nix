{ pkgs, ... }:

{
  home.packages = with pkgs; [
    neovim
    helix
    git
    ripgrep
    fzf
    jq
    just
    nvd
    gh
    jjui
    fd
    eza
    bat
    fastfetch
    zoxide
    dig
    shellcheck
    sops
    age
    ssh-to-age
    libxml2
    file
    sing-box
  ];
}

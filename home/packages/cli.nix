{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    neovim
    helix
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
    dig
    shellcheck
    sops
    age
    ssh-to-age
    libxml2
    file
    inputs.sing-box-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
    sing-box-reF1nd
  ];
}

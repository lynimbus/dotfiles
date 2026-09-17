{
  inputs,
  lib,
  username,
  ...
}:

{
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  nixpkgs.config.allowUnfree = true;

  documentation.nixos.enable = false;

  programs.nh = {
    enable = true;
    flake = "/home/${username}/nixos";
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = lib.mkForce [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.bfsu.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
    download-buffer-size = 524288000;
    auto-optimise-store = true;
    warn-dirty = false;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 3d";
  };
}

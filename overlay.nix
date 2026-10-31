{
  inputs,
  system,
  repoRoot,
}:
final: _prev: {
  grok-bot = inputs.grok-bot.packages.${system}.default;

  kero = final.callPackage ./pkgs/kero.nix { };

  magpie = final.callPackage ./pkgs/magpie.nix { };

  mygo = final.callPackage ./pkgs/mygo.nix { };

  opengrep = final.callPackage ./pkgs/opengrep.nix { };

  pig = final.callPackage ./pkgs/pig.nix { };

  r8 = final.callPackage ./pkgs/r8.nix { };

  rtk = final.callPackage ./pkgs/rtk.nix { };

  sing-box = final.callPackage ./pkgs/sing-box.nix { };

  strata = final.callPackage ./pkgs/strata.nix {
    inherit repoRoot;
  };

  strata-file-manager = final.callPackage ./pkgs/strata-file-manager.nix { };

  strata-portal = final.callPackage ./pkgs/strata-portal.nix { };
}

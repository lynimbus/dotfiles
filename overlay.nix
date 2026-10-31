{
  inputs,
  system,
  repoRoot,
}:
final: _prev: {
  grok-bot = inputs.grok-bot.packages.${system}.default;

  kero = final.callPackage ./pkgs/kero.nix { };

  lody-mygo = final.callPackage ./pkgs/lody-mygo.nix { };

  # The real Pi CLI, as Lody's ACP adapter drives it: its version rides the
  # llm-agents input, so `just update` moving flake.lock moves it too. Not
  # on PATH (pig already answers to `pi` there); lody-pi wraps it for Lody.
  pi = inputs.llm-agents.packages.${system}.pi;

  lody-pi = final.callPackage ./pkgs/lody-pi.nix { };

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

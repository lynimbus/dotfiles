{
  inputs,
  system,
  repoRoot,
}:
final: _prev:
let
  releaseLib = import ./pkgs/lib/release.nix { inherit (final) lib; };
in
{
  claude-desktop-zh = final.callPackage ./pkgs/claude-desktop-zh.nix {
    claude-desktop = inputs.llm-agents.packages.${system}.claude-desktop;
    src = inputs.claude-desktop-zh-src;
  };

  deepseek-bot = final.callPackage ./pkgs/deepseek-bot.nix {
    inherit releaseLib;
    releaseManifest = inputs.deepseek-bot-release;
  };

  magpie = final.callPackage ./pkgs/magpie.nix {
    inherit releaseLib;
    releaseManifest = inputs.magpie-release;
    upstream = inputs.magpie-src;
  };

  pi-agent-desktop = final.callPackage ./pkgs/pi-agent-desktop.nix {
    inherit releaseLib;
    releaseManifest = inputs.pi-agent-release;
  };

  pi-coding-agent = final.callPackage ./pkgs/pi-coding-agent.nix { };

  rtk = final.callPackage ./pkgs/rtk.nix {
    inherit releaseLib;
    releaseManifest = inputs.rtk-release;
  };

  sing-box-reF1nd = final.callPackage ./pkgs/sing-box-reF1nd.nix {
    package = inputs.sing-box-reF1nd-flake.packages.${system}.default;
  };

  strata = final.callPackage ./pkgs/strata.nix {
    inherit releaseLib repoRoot;
    releaseManifest = inputs.strata-release;
  };

  strata-file-manager = final.callPackage ./pkgs/strata-file-manager.nix { };

  strata-portal = final.callPackage ./pkgs/strata-portal.nix { };
}

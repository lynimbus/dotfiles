{
  inputs,
  system,
  repoRoot,
}:
final: _prev: {
  zed-editor = final.callPackage ./pkgs/zed-prebuilt.nix {
    src = inputs.zed-bin;
  };

  claude-desktop-zh = final.callPackage ./pkgs/claude-desktop-zh.nix {
    claude-desktop = inputs.llm-agents.packages.${system}.claude-desktop;
    translations = inputs.claude-desktop-zh-src;
  };

  pi-agent-desktop = final.callPackage ./pkgs/pi-agent-desktop.nix {
    releaseManifest = inputs.pi-agent-release;
  };

  deepseek-bot = final.callPackage ./pkgs/deepseek-bot.nix {
    releaseManifest = inputs.deepseek-bot-release;
  };

  rtk = final.callPackage ./pkgs/rtk.nix {
    releaseManifest = inputs.rtk-release;
  };

  pi-coding-agent = final.callPackage ./pkgs/pi-coding-agent.nix { };

  magpie-unwrapped = final.callPackage ./pkgs/magpie {
    src = inputs.magpie-src;
    releaseManifest = inputs.magpie-release;
  };

  magpie = final.callPackage ./pkgs/magpie-rtk.nix {
    magpie = final.magpie-unwrapped;
  };

  strata = final.callPackage ./pkgs/strata.nix {
    release = inputs.strata-release;
    inherit repoRoot;
  };
  strata-portal = final.callPackage ./pkgs/strata-portal.nix { };
  strata-file-manager = final.callPackage ./pkgs/strata-file-manager.nix { };

  sing-box-reF1nd =
    let
      pkg = inputs.sing-box-reF1nd-flake.packages.${system}.default;
    in
    final.symlinkJoin {
      name = "sing-box-reF1nd";
      paths = [ pkg ];
      postBuild = ''
        mv "$out/bin/sing-box" "$out/bin/sing-box-reF1nd"
        rm -rf "$out/share" "$out/lib/systemd"
      '';
    };
}

{
  description = "lynimbus's nixos flake configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyclipsync = {
      url = "github:ryan4yin/pyclipsync/v0.1.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    magpie-flake = {
      url = "github:mtul0729/magpie-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sing-box-flake = {
      url = "github:rxda/sing-box-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sing-box-reF1nd-flake = {
      url = "github:lynimbus/sing-box-reF1nd-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-style-plymouth = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zed-bin = {
      url = "https://zed.dev/api/releases/preview/latest/zed-linux-x86_64.tar.gz";
      flake = false;
    };

    strata-release = {
      url = "https://github.com/lgse/strata/releases/latest/download/strata-update-manifest.json";
      flake = false;
    };

    claude-desktop-zh-src = {
      url = "github:javaht/claude-desktop-zh-cn";
      flake = false;
    };

    pi-agent-release = {
      url = "https://api.github.com/repos/abcwyc/pi-agent-desktop/releases/latest";
      flake = false;
    };

    rtk-release = {
      url = "https://api.github.com/repos/rtk-ai/rtk/releases/latest";
      flake = false;
    };

    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia.url = "github:noctalia-dev/noctalia/cachix";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      hostname = "nixos";
      username = "lynimbus";
      email = "128837704+lynimbus@users.noreply.github.com";

      localOverlay = final: _prev: {
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

        rtk = final.callPackage ./pkgs/rtk.nix {
          releaseManifest = inputs.rtk-release;
        };

        pi-coding-agent = final.callPackage ./pkgs/pi-coding-agent.nix { };

        magpie = final.callPackage ./pkgs/magpie.nix {
          upstream = inputs.magpie-flake.packages.${system}.magpie;
        };

        strata = final.callPackage ./pkgs/strata.nix {
          release = inputs.strata-release;
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
      };
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs hostname username; };
        modules = [
          {
            nixpkgs.overlays = [ localOverlay ];
          }
          inputs.nixos-hardware.nixosModules.mechrevo-gm5hg0a
          inputs.mangowm.nixosModules.mango
          ./system/init.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs username email; };
            home-manager.users.${username} = ./home/init.nix;
            home-manager.backupFileExtension = "old";
          }
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      checks.${system}.commit-style =
        nixpkgs.legacyPackages.${system}.runCommandLocal "commit-style"
          {
            nativeBuildInputs = [ nixpkgs.legacyPackages.${system}.bash ];
          }
          ''
            export HOME=$TMPDIR
            cp -r ${./docs} docs
            chmod +x docs/lint-commit-message.sh docs/lint-commit-message.test.sh
            bash docs/lint-commit-message.test.sh
            touch $out
          '';
    };
}

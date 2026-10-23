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

    deepseek-bot-release = {
      url = "https://api.github.com/repos/Fei2411/DeepSeek-Bot/releases/latest";
      flake = false;
    };

    rtk-release = {
      url = "https://api.github.com/repos/rtk-ai/rtk/releases/latest";
      flake = false;
    };

    magpie-release = {
      url = "https://api.github.com/repos/yetone/magpie/releases/latest";
      flake = false;
    };

    magpie-src = {
      url = "github:yetone/magpie";
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

      homeDirectory = "/home/${username}";
      repoRoot = "${homeDirectory}/dotfiles";

      sshKey = "${homeDirectory}/.ssh/id_ed25519";

      localOverlay = import ./overlay.nix { inherit inputs system repoRoot; };
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit
            inputs
            hostname
            username
            homeDirectory
            repoRoot
            ;
        };
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
            home-manager.extraSpecialArgs = {
              inherit
                inputs
                username
                email
                homeDirectory
                repoRoot
                sshKey
                ;
            };
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

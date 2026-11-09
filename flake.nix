{
  description = "lynimbus's nixos flake configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
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

    linuxqq-wayland-fix = {
      url = "github:SHORiN-KiWATA/linuxqq-wayland-fix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-style-plymouth = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme";
      inputs.nixpkgs.follows = "nixpkgs";
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

      local = import ./overlay.nix {
        inherit repoRoot;
        lib = nixpkgs.lib;
      };

      # One set of arguments for the system and the home modules, so a value
      # reaches whichever module needs it without a second list to maintain.
      moduleArgs = {
        inherit
          inputs
          hostname
          username
          email
          homeDirectory
          repoRoot
          sshKey
          ;
      };
    in
    {
      # nix-update rewrites a package through this attribute path, and
      # `nix build .#legacyPackages.${system}.<pkg>` builds one package on its
      # own. It is deliberately not the nixosConfigurations pkgs set: that one
      # hangs off the module fixpoint and is slow to evaluate per package.
      # allowUnfree mirrors system/nix.nix, or the BSL packages (rtk, strata)
      # would fail checkMeta here.
      legacyPackages.${system} =
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ local.overlay ];
        }
        // {
          # Per package, the nix-update flags its file declares in
          # passthru.bump, or null for a package that does not track a release of
          # its own. docs/bump-packages.sh runs from this, so adding a package
          # never means editing the script.
          bumpMatrix = builtins.listToAttrs (
            map (name: {
              inherit name;
              value = self.legacyPackages.${system}.${name}.passthru.bump or null;
            }) local.names
          );
        };

      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = moduleArgs;
        modules = [
          {
            nixpkgs.overlays = [ local.overlay ];
          }
          inputs.nixos-hardware.nixosModules.mechrevo-gm5hg0a
          inputs.mangowm.nixosModules.mango
          inputs.linuxqq-wayland-fix.nixosModules.default
          ./system/init.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = moduleArgs;
            home-manager.users.${username} = ./home/init.nix;
            home-manager.backupFileExtension = "old";
          }
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}

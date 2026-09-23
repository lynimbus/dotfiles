{
  description = "lynimbus's nixos flake configuration";

  inputs = {
    nixpkgs.url = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixos-unstable/nixexprs.tar.xz";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
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

    mac-style-plymouth = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

      pkgs = nixpkgs.legacyPackages.${system};

      mkLocalPkgs = p: {
        zed-editor = p.callPackage ./pkgs/zed-prebuilt.nix { };
        qingjian = p.callPackage ./pkgs/qingjian/package.nix { };
      };

      localOverlay = final: _prev: mkLocalPkgs final;
    in
    {
      packages.${system} = mkLocalPkgs pkgs;

      apps.${system}.update-pkgs =
        let
          script = pkgs.writeShellApplication {
            name = "update-pkgs";
            runtimeInputs = [
              pkgs.nix-update
              pkgs.git
              pkgs.nix
              pkgs.gh
              pkgs.gnugrep
            ];
            text = ''
              current=$(nix eval --raw .#zed-editor.version)
              latest=$(gh release view --repo LI-NA/zed-i18n --json tagName --jq '.tagName | sub("^v"; "")')
              if [ "$current" = "$latest" ]; then
                echo "zed-editor: already up to date ($current)"
              else
                echo "zed-editor: updating $current -> $latest"
                nix-update --flake --version-regex '^v?(\d+\.\d+\.\d+-i18n\.\d+)$' zed-editor
              fi

              current=$(nix eval --raw .#qingjian.src.rev)
              latest=$(gh api repos/qingjian-team/qingjian/commits/HEAD --jq .sha)
              if [ "$current" = "$latest" ]; then
                echo "qingjian: already up to date ($current)"
              else
                # shellcheck disable=SC2016
                grep -qF 'version = "0.1.3-unstable-''${lib.substring 0 8 rev}"' pkgs/qingjian/package.nix \
                  || { echo "qingjian: version no longer derives from rev, refusing to auto-update" >&2; exit 1; }
                echo "qingjian: updating $current -> $latest"
                nix-update --flake --version=branch qingjian
              fi
            '';
          };
        in
        {
          type = "app";
          program = "${script}/bin/update-pkgs";
        };
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs hostname username; };
        modules = [
          {
            nixpkgs.overlays = [ localOverlay ];
          }
          inputs.nixos-hardware.nixosModules.mechrevo-gm5hg0a
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

      formatter.${system} = pkgs.nixfmt-tree;
    };
}

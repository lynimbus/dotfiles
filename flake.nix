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

    llm-agents.url = "github:numtide/llm-agents.nix";
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
        pi-coding-agent = p.callPackage ./pkgs/pi-main.nix { };
        magpie = p.callPackage ./pkgs/magpie.nix { };
      };

      localOverlay = final: _prev: mkLocalPkgs final;
    in
    {
      packages.${system} = mkLocalPkgs pkgs;

      apps.${system}.update-pkgs =
        let
          # `nix-update` evaluates packages with `nix-instantiate --eval`, which
          # implies `--readonly-mode`: derivations are not written to the store,
          # so import-from-derivation cannot instantiate its sources and aborts
          # with: error: path '<hash>-source.drv' is not valid
          # pkgs/pi-main.nix reads its version from the fetched source, so give
          # nix-update a nix whose nix-instantiate evaluates read-write.
          nix-read-write = pkgs.symlinkJoin {
            name = "nix-read-write";
            paths = [ pkgs.nix ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              rm -f $out/bin/nix-instantiate
              makeWrapper ${pkgs.lib.getExe' pkgs.nix "nix-instantiate"} \
                $out/bin/nix-instantiate --add-flags --read-write-mode
            '';
          };
          nix-update = pkgs.nix-update.override { nix = nix-read-write; };

          script = pkgs.writeShellApplication {
            name = "update-pkgs";
            runtimeInputs = [
              nix-update
              pkgs.git
              pkgs.nix
            ];
            text = ''
              nix-update --flake --version=branch \
                --custom-dep modelData \
                pi-coding-agent

              # Prebuilt assets require a published release, not just a tag.
              nix-update --flake --use-github-releases \
                --version-regex '^v?(\d+\.\d+\.\d+-i18n\.\d+)$' \
                zed-editor

              nix-update --flake --version=branch \
                --custom-dep data \
                qingjian

            '';
          };
        in
        {
          type = "app";
          program = "${script}/bin/update-pkgs";
          meta.description = "Update package versions for local packages";
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

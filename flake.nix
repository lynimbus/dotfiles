{
  description = "flake config";

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #    nur = {
    #      url = "github:nix-community/NUR";
    #      inputs.nixpkgs.follows = "nixpkgs";
    #    };

    deepseek-harness = {
      url = "github:moraxyc/deepseek-harness.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # disko.url = "github:nix-community/disko";

    # sops-nix = {
    #   url = "github:Mic92/sops-nix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      home-manager,
      deepseek-harness,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      hosts = [ "flakeos" ];
      username = "lynimbus";
      email = "128837704+lynimbus@users.noreply.github.com";

      lib = nixpkgs.lib;

      mkSystem =
        hostname:
        lib.nixosSystem {
          inherit system;

          specialArgs = { inherit inputs hostname; };

          modules = [
            nixos-hardware.nixosModules.mechrevo-gm5hg0a
            { nixpkgs.overlays = [ deepseek-harness.overlays.default ]; }

            ./hosts/${hostname}/configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "bak";
                extraSpecialArgs = {
                  inherit
                    inputs
                    hostname
                    username
                    email
                    ;
                };
                users.${username} = import ./home/${hostname}.nix;
              };
            }
          ];
        };
    in
    {
      nixosConfigurations = lib.genAttrs hosts mkSystem;

      # overlays = {
      #   default = final: prev: {
      #     # my-pkg = final.callPackage ./pkgs/my-pkg { };
      #   };
      # };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      # devShells.${system}.default =
      #   nixpkgs.legacyPackages.${system}.mkShell
      #   {
      #     packages = with nixpkgs.legacyPackages.${system}; [ git jq ripgrep ];
      #   };
    };
}

{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    alejandra = {
      url = "github:kamadorueda/alejandra";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    daeuniverse = {
      url = "github:daeuniverse/flake.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nur,
    home-manager,
    alejandra,
    sops-nix,
    daeuniverse,
    zen-browser,
    ...
  }: let
    inherit (self) outputs;
    system = "x86_64-linux";
  in {
    packages.${system} = import ./pkgs nixpkgs.legacyPackages.${system};
    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;
    overlays = import ./overlays {inherit inputs;};

    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
        };
        modules = [
          ./nixos/configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.lantianx = import ./home/home.nix;
              extraSpecialArgs = {inherit inputs outputs;};
              backupFileExtension = "";
            };
          }

          nur.modules.nixos.default
          nur.legacyPackages."${system}".repos.iopq.modules.xraya
          daeuniverse.nixosModules.dae
          sops-nix.nixosModules.sops
        ];
      };
    };
  };
}

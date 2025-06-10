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
    daeuniverse.url = "github:daeuniverse/flake.nix";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nur,
    home-manager,
    daeuniverse,
    alejandra,
    sops-nix,
    ...
  }: {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./hosts/nixos/configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lantianx = import ./home/lantianx/home.nix;
            home-manager.extraSpecialArgs = inputs;
            home-manager.backupFileExtension = "backup";
          }

          nur.modules.nixos.default
          nur.legacyPackages."${system}".repos.iopq.modules.xraya
          daeuniverse.nixosModules.dae
          sops-nix.nixosModules.sops
          {
            environment.systemPackages = [
              alejandra.defaultPackage.${system}
            ];
          }
        ];
      };
    };
  };
}

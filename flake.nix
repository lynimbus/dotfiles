{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay.url = "github:oxalica/rust-overlay";
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
    hyprland,
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
          sops-nix.nixosModules.sops
          daeuniverse.nixosModules.dae
        ];
      };
    };
  };
}

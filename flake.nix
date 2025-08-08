{
  description = "nixos flake config";

  inputs = {
    nixos-hardware.url = "github:lynimbus/nixos-hardware";
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixos-unstable";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    linux-xanmod-bore = {
      url = "github:micros24/linux-xanmod-bore";
      flake = false;
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      # url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    daeuniverse = {
      url = "github:daeuniverse/flake.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    alejandra = {
      url = "github:kamadorueda/alejandra";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixos-hardware,
    nixpkgs,
    linux-xanmod-bore,
    home-manager,
    nur,
    daeuniverse,
    alejandra,
    ...
  }: let
    inherit (self) outputs;
    system = "x86_64-linux";
  in {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          nixos-hardware.nixosModules.mechrevo-gm5hg0a

          ./configuration.nix
          nur.modules.nixos.default
          daeuniverse.nixosModules.dae
          daeuniverse.nixosModules.daed

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.lantianx = import ./home.nix;
              extraSpecialArgs = {inherit inputs outputs;};
              backupFileExtension = "backup";
            };
          }
        ];
      };
    };
  };
}

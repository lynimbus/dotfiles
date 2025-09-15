{
  description = "nixos flake config";

  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
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

    mac-style-plymouth = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    kickstart-nixvim.url = "github:JMartJonesy/kickstart.nixvim";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    import-tree.url = "github:vic/import-tree";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      nur,
      daeuniverse,
      ...
    }:
    let
      inherit (self) outputs;
      system = "x86_64-linux";
      hostname = "nixos";
      username = "lantianx";
      email = "lantianx233@gmail.com";
    in
    {
      nixosConfigurations = {
        ${hostname} = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              outputs
              hostname
              username
              email
              ;
          };
          modules = [
            ./configuration.nix

            nixos-hardware.nixosModules.mechrevo-gm5hg0a
            nur.modules.nixos.default
            daeuniverse.nixosModules.dae
            daeuniverse.nixosModules.daed

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${username} = import ./home.nix;
                extraSpecialArgs = {
                  inherit
                    inputs
                    outputs
                    hostname
                    username
                    email
                    ;
                };
                backupFileExtension = "bak";
              };
            }
          ];
        };
      };
    };
}

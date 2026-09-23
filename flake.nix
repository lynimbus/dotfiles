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

      localOverlay = final: _prev: {
        zed-editor = final.callPackage ./pkgs/zed-prebuilt.nix { };
        qingjian = final.callPackage ./pkgs/qingjian/package.nix { };
      };
    in
    {
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

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}

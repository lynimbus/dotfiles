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

    # mac-style plymouth 开机动画主题（旧配置沿用）
    mac-style-plymouth = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri-glass：带 liquid-glass 液态玻璃补丁的 niri（旧配置在 Arch 侧是
    # pkgs/niri-glass/PKGBUILD，换 Nix 实现就是这个 flake；它自己钉 niri 26.04
    # rev 49fc611 + 对应 overlay，nixpkgs follows niri/nixpkgs）。
    niri-glass = {
      url = "github:zaroutt/Niri-glass";
    };

    # kickstart.nixvim：声明式 nvim 全家桶（旧配置沿用）。
    # vendored 在 inputs/ 里（修掉 nixpkgs-unstable 已移除 tmux grammar 的硬错误）。
    kickstart-nixvim = {
      url = "./inputs/kickstart-nixvim-flake";
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

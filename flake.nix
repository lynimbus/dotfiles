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

    deepseek-harness = {
      url = "github:moraxyc/deepseek-harness.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-style-plymouth = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-glass = {
      url = "github:zaroutt/Niri-glass";
    };

    niri-flake = {
      url = "github:epireyn/niri-flake";
    };

    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixos-hardware,
      home-manager,
      deepseek-harness,
      zig-overlay,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      username = "lynimbus";
      email = "128837704+lynimbus@users.noreply.github.com";

      glassOverlay =
        final: _prev:
        let
          glass = inputs.niri-glass;
        in
        {
          niri-glass = final.niri-stable.overrideAttrs (old: {
            pname = "niri-glass";
            postPatch = (old.postPatch or "") + ''
              echo "==> Applying Niri-glass liquid-glass overlay"
              chmod -R u+w src/render_helpers niri-config/src
              cp --no-preserve=mode ${glass}/src/render_helpers/liquid_glass.rs              src/render_helpers/liquid_glass.rs
              cp --no-preserve=mode ${glass}/src/render_helpers/background_effect.rs         src/render_helpers/background_effect.rs
              sed -i 's/warn!(\("LIQUID GLASS\)/debug!(\1/' src/render_helpers/background_effect.rs
              cp --no-preserve=mode ${glass}/src/render_helpers/framebuffer_effect.rs        src/render_helpers/framebuffer_effect.rs
              cp --no-preserve=mode ${glass}/src/render_helpers/xray.rs                      src/render_helpers/xray.rs
              cp --no-preserve=mode ${glass}/src/render_helpers/mod.rs                       src/render_helpers/mod.rs
              cp --no-preserve=mode ${glass}/src/render_helpers/shaders/clipped_surface.frag src/render_helpers/shaders/clipped_surface.frag
              cp --no-preserve=mode ${glass}/src/render_helpers/shaders/mod.rs               src/render_helpers/shaders/mod.rs
              cp --no-preserve=mode ${glass}/niri-config/src/appearance.rs                   niri-config/src/appearance.rs
            '';
            meta = (old.meta or { }) // {
              description = "niri-stable with liquid-glass / refraction background effect (patch from zaroutt/Niri-glass)";
              homepage = "https://github.com/zaroutt/Niri-glass";
            };
          });
        };

      zedOverlay = final: _prev: {
        zed-editor = final.callPackage ./pkgs/zed-prebuilt.nix { };
      };
    in
    {
      nixosConfigurations.flakeos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs username; };
        modules = [
          nixos-hardware.nixosModules.mechrevo-gm5hg0a
          {
            nixpkgs.overlays = [
              deepseek-harness.overlays.default
              inputs.niri-flake.overlays.niri
              glassOverlay
              zedOverlay
              zig-overlay.overlays.default
            ];
          }
          ./hosts/flakeos/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              extraSpecialArgs = {
                inherit inputs username email;
              };
              users.${username} = import ./home/flakeos.nix;
            };
          }
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}

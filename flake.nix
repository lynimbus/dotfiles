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

    # mac-style plymouth 开机动画主题
    mac-style-plymouth = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri-glass：liquid-glass 液态玻璃补丁源码集。只用它的源文件当补丁：
    # glassOverlay 把这些文件覆盖到下方 niri-flake 的 niri-stable（v26.04）
    # 之上重新构建，产出 pkgs.niri-glass。不使用它的 nixosModule。
    niri-glass = {
      url = "github:zaroutt/Niri-glass";
    };

    # epireyn/niri-flake：sodiboo/niri-flake 的维护性 fork。
    # 提供 niri-stable (v26.04) 包、home-manager 的 programs.niri.settings
    # （构建期经 `niri validate` 校验后生成 ~/.config/niri/config.kdl）。
    # 不 follow nixpkgs：包按它自己的锁版本构建，最大化 niri-epireyn.cachix.org
    # 缓存命中。NixOS 会话走 nixpkgs 的 programs.niri，home 配置走它的
    # homeModules.config。
    niri-flake = {
      url = "github:epireyn/niri-flake";
    };

    # zed-editor 走 pkgs/zed-prebuilt.nix（官方 GitHub release 预编译 zip）。
    # 不锁官方 flake：官方 flake 只提供源码编译（1h+）且 CI 不推主包缓存。

    # zig-overlay：mitchellh 维护的官方 Zig 预编译镜像。
    # 用法：pkgs.zigpkgs.master（最新 master）、pkgs.zigpkgs."0.16.0" 等。
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

      # liquid-glass 补丁 applied over niri-flake 的 niri-stable（v26.04）。
      # 必须排在 niri-flake 的 overlays.niri 之后（依赖 final.niri-stable）。
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
              # liquid-glass 在 update_render_elements 里每帧 warn!（niri 进程日志被
              # "LIQUID GLASS: update_render_elements" 刷屏），降成 debug!。sed 只命中
              # 这两条 LIQUID GLASS 噪音，文件里其他 warn!（着色器编译失败等）保留。
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

      # 覆盖 nixpkgs 的 zed-editor 为官方预编译 zip（home-manager 默认吃这个包名）。
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

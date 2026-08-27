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

    # niri-glass：liquid-glass 液态玻璃补丁源码集（旧配置在 Arch 侧是
    # pkgs/niri-glass/PKGBUILD）。本仓现在只用它的 overlay 文件当补丁源：
    # glassOverlay（见下方 outputs）把这些文件覆盖到下方 niri-flake 的
    # niri-stable（同为 26.04，8 个被替换文件与补丁基线修订逐字节一致）之上
    # 重新构建，产出 pkgs.niri-glass。不再使用它的 nixosModule。
    niri-glass = {
      url = "github:zaroutt/Niri-glass";
    };

    # epireyn/niri-flake：sodiboo/niri-flake 的维护性 fork。
    # 提供 niri-stable (v26.04) / niri-unstable 包、NixOS/home-manager 模块，
    # 以及声明式配置 programs.niri.settings|config（构建期经 `niri validate`
    # 校验后生成 ~/.config/niri/config.kdl）。
    # 不 follow nixpkgs：包按它自己的锁版本构建，最大化 niri-epireyn.cachix.org
    # 缓存命中（模块默认自动注册该 substituter）。
    niri-flake = {
      url = "github:epireyn/niri-flake";
    };

    # zed-editor：官方发布预编译版（pkgs/zed-prebuilt.nix，下载 GitHub release zip，
    # 秒装不编译）。版本/hash 由 scripts/update-zed.sh 自动维护（just update-zed）。
    # 不锁官方 flake input：官方 flake 只提供源码编译（1h+）且 CI 不推主包缓存，
    # 而官方 GitHub release 的预编译 zip 是唯一免编译路径。

    # zig-overlay：mitchellh 维护的官方 Zig 预编译镜像，每天同步官方 master 构建。
    # 升级：nix flake update zig-overlay → just switch。
    # 用法：pkgs.zigpkgs.master（最新 master）、pkgs.zigpkgs."0.16.0" 等任意版本。
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
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
      zig-overlay,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      hosts = [ "flakeos" ];
      username = "lynimbus";
      email = "128837704+lynimbus@users.noreply.github.com";

      lib = nixpkgs.lib;

      # liquid-glass 补丁 applied over niri-flake 的 niri-stable（v26.04）。
      # 必须排在 niri-flake 的 overlays.niri 之后应用（依赖 final.niri-stable）。
      # 补丁 = 整文件覆盖（见 inputs.niri-glass 注释），只动 niri crate 本身，
      # 不改 Cargo.lock，依赖集与上游一致。
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

      # zed-editor：官方 GitHub release 预编译 zip（秒装不编译）。
      # 版本/hash 由 scripts/update-zed.sh 维护（just update-zed）。
      # 同时提供 `zed-editor`（新名）与 `zed-prebuilt`（兼容旧引用）。
      zedOverlay = final: _prev: {
        zed-editor = final.callPackage ./pkgs/zed-prebuilt.nix { };
        # 兼容旧引用名（home/flakeos.nix programs.zed-editor.package）
        zed-prebuilt = final.callPackage ./pkgs/zed-prebuilt.nix { };
      };

      # zig：mitchellh/zig-overlay 的 overlay 注册 `zigpkgs`（含 master/任意版本）。
      # 最新 master：pkgs.zigpkgs.master；稳定版：pkgs.zigpkgs.default。

      # koka：直接用 nixpkgs-unstable 的 release 版（3.2.3，跟随 nixpkgs 通道更新），
      # 不再自维护 master 源码构建（一次 Haskell 全量编译几十分钟，性价比低）。

      mkSystem =
        hostname:
        lib.nixosSystem {
          inherit system;

          specialArgs = { inherit inputs hostname; };

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

      # 独立暴露，便于单独构建/试用：
      #   nix build .#zed-editor .#zig-master .#koka
      #   nix run .#zig-master
      packages.${system} = {
        # zed-editor：官方 release 预编译 zip（版本由 just update-zed 维护）
        zed-editor = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/zed-prebuilt.nix { };
        # 兼容旧引用名
        zed-prebuilt = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/zed-prebuilt.nix { };

        # zig：zig-overlay 提供的最新 master 版本
        zig-master = inputs.zig-overlay.packages.${system}.master;

        # koka：nixpkgs-unstable 的 release 版本（跟随通道更新）
        koka = nixpkgs.legacyPackages.${system}.koka;
      };

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

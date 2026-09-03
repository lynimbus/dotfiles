{ inputs }:

let
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
    zed-editor = final.callPackage ../pkgs/zed-prebuilt.nix { };
    # 兼容旧引用名（home/flakeos.nix programs.zed-editor.package）
    zed-prebuilt = final.callPackage ../pkgs/zed-prebuilt.nix { };
  };

  # zig：mitchellh/zig-overlay 的 overlay 注册 `zigpkgs`（含 master/任意版本）。
  # 最新 master：pkgs.zigpkgs.master；稳定版：pkgs.zigpkgs.default。

  # koka：直接用 nixpkgs-unstable 的 release 版（3.2.3，跟随 nixpkgs 通道更新），
  # 不再自维护 master 源码构建（一次 Haskell 全量编译几十分钟，性价比低）。

in
[
  inputs.deepseek-harness.overlays.default
  inputs.niri-flake.overlays.niri
  glassOverlay
  zedOverlay
  inputs.zig-overlay.overlays.default
]

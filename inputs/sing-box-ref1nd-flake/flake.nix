{
  description = "reF1nd/sing-box（reF1nd-testing 分支，带 eBPF）的 Nix 打包";

  inputs = {
    # 跟随 nixpkgs 稳定分支；如需滚动更新可改成 github:NixOS/nixpkgs/nixos-unstable
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # 源码直接跟踪 reF1nd-testing 分支的最新提交（不是锁定死的版本）：
    #   nix flake update sing-box-src   # 拉到分支最新 commit
    #   nix flake lock --update-input sing-box-src
    # 具体锁定到哪个 commit 由 flake.lock 记录，可复现。
    sing-box-src = {
      url = "github:reF1nd/sing-box/reF1nd-testing";
      flake = false; # 只取源码，不当作独立 flake
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      sing-box-src,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgName = "sing-box-ref1nd";

      # 当前锁定的提交（用于版本号），非 git 输入时回退
      srcRev = sing-box-src.rev or "unknown";

      # 包参数：跟踪分支源码 + 默认启用 eBPF
      mkPackage =
        pkgs:
        pkgs.callPackage ./pkgs/sing-box-ref1nd.nix {
          src = sing-box-src;
          inherit srcRev;
          withEBPF = true;
        };
    in
    {
      # ── 直接构建：nix build .#sing-box-ref1nd（或 .#default）──
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          ${pkgName} = mkPackage pkgs;
          default = self.packages.${system}.${pkgName};
        }
      );

      # ── overlay：在别的 flake / 配置里用
      #    inputs.sing-box-ref1nd.url = "path:/path/to/this-flake";
      #    overlays = [ sing-box-ref1nd.overlays.default ];
      #    然后 services.sing-box.package = pkgs.sing-box-ref1nd; ──
      overlays.default = final: prev: {
        ${pkgName} = mkPackage final;
      };

      # ── 冒烟测试：nix flake check --no-build ──
      checks = forAllSystems (system: {
        inherit (self.packages.${system}) default;
      });

      # ── 代码格式化：nix fmt ──
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}

{
  pkgs,
  lib,
  sccache,
  ...
}:

let
  # Share sccache with Nix sandbox builds once systemd-tmpfiles has created it,
  # falling back to ~/.cache/sccache beforehand so cargo never fails before the
  # first switch.
  sccacheWrapper = pkgs.writeShellScript "cargo-sccache-wrapper" ''
    if [ -d ${sccache.dir} ] && [ -w ${sccache.dir} ]; then
      export SCCACHE_DIR="${sccache.dir}"
    fi
    exec ${lib.getExe pkgs.sccache} "$@"
  '';
in
{
  home.sessionVariables = {
    SCCACHE_CACHE_SIZE = sccache.cacheSize;
  };

  # Global Cargo defaults: cache every crate with sccache across projects and
  # link native Linux binaries with mold. Kept scoped to x86_64-unknown-linux-gnu
  # so Android/wasm cross-compilation via rustup keeps its own target linker.
  home.file.".cargo/config.toml".text = ''
    [build]
    rustc-wrapper = "${sccacheWrapper}"

    [target.x86_64-unknown-linux-gnu]
    linker = "${lib.getExe' pkgs.clang "clang"}"
    rustflags = ["-C", "link-arg=-fuse-ld=${lib.getExe' pkgs.mold "ld.mold"}"]
  '';
}

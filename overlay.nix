# Every consumer (nix-update, the bump script, the scaffold) reads the same
# list of names. callPackage only gets this repo's checkout path or the
# configured craneLib for the packages whose arguments ask for them.
{
  lib,
  repoRoot,
  crane,
  sccache,
}:
let
  names = map (lib.removeSuffix ".nix") (
    builtins.filter (lib.hasSuffix ".nix") (builtins.attrNames (builtins.readDir ./pkgs))
  );

  # Shared Crane library for local Rust derivations: link with mold and
  # opportunistically enable sccache whenever the shared cache directory is
  # mounted inside the sandbox, so failed or incremental rebuilds keep crate caches.
  mkCraneLib =
    final:
    (crane.mkLib final).overrideScope (
      _cFinal: cPrev: {
        stdenvSelector = p: p.stdenvAdapters.useMoldLinker p.stdenv;
        mkCargoDerivation =
          args:
          cPrev.mkCargoDerivation (
            args
            // {
              nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [ final.sccache ];
              preBuild = ''
                if [ -d ${sccache.dir} ] && [ -w ${sccache.dir} ]; then
                  export RUSTC_WRAPPER="${lib.getExe final.sccache}"
                  export SCCACHE_DIR="${sccache.dir}"
                  export SCCACHE_CACHE_SIZE="${sccache.cacheSize}"
                fi
              ''
              + (args.preBuild or "");
            }
          );
      }
    );

  call =
    final: craneLib: name:
    let
      file = ./pkgs + "/${name}.nix";
      fnArgs = builtins.functionArgs (import file);
      extra =
        lib.optionalAttrs (fnArgs ? repoRoot) { inherit repoRoot; }
        // lib.optionalAttrs (fnArgs ? craneLib) { inherit craneLib; };
    in
    final.callPackage file extra;
in
{
  inherit names;

  overlay =
    final: _prev:
    let
      craneLib = mkCraneLib final;
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = call final craneLib name;
      }) names
    );
}

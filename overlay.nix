# Every consumer (nix-update, the bump script, the scaffold) reads the same
# list of names. callPackage only gets this repo's checkout path or the
# shared MyGo builder for the packages whose arguments ask for them.
{
  lib,
  repoRoot,
}:
let
  names = map (lib.removeSuffix ".nix") (
    builtins.filter (lib.hasSuffix ".nix") (builtins.attrNames (builtins.readDir ./pkgs))
  );

  call =
    final: buildMyGoApp: name:
    let
      file = ./pkgs + "/${name}.nix";
      fnArgs = builtins.functionArgs (import file);
      extra =
        lib.optionalAttrs (fnArgs ? repoRoot) { inherit repoRoot; }
        // lib.optionalAttrs (fnArgs ? buildMyGoApp) { inherit buildMyGoApp; };
    in
    final.callPackage file extra;
in
{
  inherit names;

  overlay =
    final: prev:
    let
      buildMyGoApp = final.callPackage ./lib/build-mygo-app.nix { };
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = call final buildMyGoApp name;
      }) names
    )
    // {
      # Keep nixpkgs' cached beads derivation instead of rebuilding its ~9 min Go
      # build + test suite whenever pkgs/dolt.nix overrides pkgs.dolt.
      beads = prev.beads.override { dolt = prev.dolt; };
    };
}

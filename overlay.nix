# Every consumer (nix-update, the bump script, the scaffold) reads the same
# list of names. callPackage only gets this repo's checkout path for the
# packages whose arguments ask for it.
{ lib, repoRoot }:
let
  names = map (lib.removeSuffix ".nix") (
    builtins.filter (lib.hasSuffix ".nix") (builtins.attrNames (builtins.readDir ./pkgs))
  );

  call =
    final: name:
    let
      file = ./pkgs + "/${name}.nix";
      wantsRepoRoot = builtins.functionArgs (import file) ? repoRoot;
    in
    final.callPackage file (lib.optionalAttrs wantsRepoRoot { inherit repoRoot; });
in
{
  inherit names;

  overlay =
    final: _prev:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = call final name;
      }) names
    );
}

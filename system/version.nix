{ inputs, lib, ... }:

let
  nixpkgsSrc = "${inputs.nixpkgs}";
  revisionFile = "${nixpkgsSrc}/.git-revision";
  revision = builtins.substring 0 7 (lib.removeSuffix "\n" (builtins.readFile revisionFile));
in
{
  system.nixos.versionSuffix = lib.mkIf (builtins.pathExists revisionFile) (
    lib.mkForce ".${revision}"
  );
}

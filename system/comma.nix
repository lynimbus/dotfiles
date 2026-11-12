{
  inputs,
  pkgs,
  ...
}:

let
  # nixpkgs ships `programs.comma`, but everything it installs names the
  # unwrapped comma binary, and that binary resolves a program name through a
  # nix-index database under ~/.cache. Nothing builds one here, so the handler
  # fails with "database does not exist" instead of running the program.
  #
  # nix-index-database publishes the index file itself. nix-locate wants a
  # directory holding it under the name `files`, which is what the package in
  # this flake wraps with linkFarm.
  db = inputs.nix-index-database.packages.${pkgs.stdenv.hostPlatform.system}.nix-index-small-database;

  # The upstream shell hooks call the bare binary, so export the directory
  # rather than patch those hooks. The comma binary itself is stock.
  dbDir = pkgs.linkFarm "nix-index-database" { files = db; };
in
{
  environment.sessionVariables.NIX_INDEX_DATABASE = "${dbDir}";

  programs.comma.enable = true;
}

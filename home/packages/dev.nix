{ pkgs, ... }:

let
  # nix-init resolves builder arguments and prefetches hashes against a nixpkgs
  # it evaluates itself. Pin it to the revision this configuration is built with
  # so a generated package names arguments that exist in the nixpkgs that will
  # actually build it, instead of whatever the channel happens to hold.
  nixpkgs = "${pkgs.path}";
in
{
  home.packages = with pkgs; [
    nix-init
    nixfmt
    zig
    koka
    go
    android-tools
    payload-dumper-go
    python3
    nodejs
    nil
    nixd
  ];

  # Scaffolding only: generate into a scratch directory, then port the result
  # into pkgs/*.nix by hand. The overlay takes its hashes from release
  # manifests, so a sha256 written into the file would be a second, conflicting
  # update path.
  xdg.configFile."nix-init/config.toml".text = ''
    # nixpkgs used to resolve builder arguments and prefetch hashes.
    nixpkgs = '${nixpkgs}'

    # Nothing here lives in a nixpkgs by-name tree, and this repository is
    # driven by jj, so nix-init must never commit on its own.
    commit = false

    # nix-init only detects nixfmt if it is on PATH; name it explicitly. The
    # bare form warns that it will stop reading stdin anonymously, so say "-".
    [format]
    command = ["nixfmt", "-"]

    # Every run asks the GitHub API for the description, the releases, the tags
    # and the recent commits, and the anonymous quota is 60 an hour per IP. gh
    # already holds a token in the keyring, so read it from there instead of
    # keeping a secret in this repository.
    [access-tokens]
    "github.com".command = ["gh", "auth", "token"]
  '';
}

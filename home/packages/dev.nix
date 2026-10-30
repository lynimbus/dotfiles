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
    mygo
    android-tools
    payload-dumper-go
    python3
    nodejs
    nil
    nixd
    # Java: the Eclipse JDT language server (nixpkgs wraps it with its own
    # JDK, so `jdtls` runs standalone and pi-lens stops reporting "java
    # analysis unavailable") plus a plain JDK 17 for javac/java work and the
    # r8 wrapper below.
    jdt-language-server
    openjdk17
    # Diagnostic runners pi-lens resolves from PATH. With opengrep found
    # there the lens never falls back to its own installer, which would
    # fetch the GitHub binary unpatched for NixOS.
    ast-grep
    typos
    opengrep
    # Reverse-engineering toolchain for shipped Android artefacts: ELF
    # inspection, dex/apk decompiling, and the EROFS images modern Android
    # ships its system partitions in.
    binutils
    llvm
    jadx
    apktool
    erofs-utils
    # d8/r8 dexer from Google Maven (overlay) — the one piece of the Android
    # build chain nixpkgs does not carry, so Java can be compiled to dex
    # instead of hand-writing smali.
    r8
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

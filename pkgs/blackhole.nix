{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  bash,
  coreutils,
  findutils,
  gawk,
  gnugrep,
  gnused,
  perl,
  procps,
  util-linux,
  # Upstream tags no release, so the commit is the version and nix-update has
  # nothing to enumerate: this file declares no passthru.bump, rev/version/hash
  # move together by hand.
  #
  # Blackhole is a Bash launcher, not a built program. It resolves ROOT_DIR as
  # the directory above bin/, and uses that same directory as both the source of
  # lib/docker-backend.sh and the context of the `docker build` that produces
  # the image Claude Code runs in. So the whole checkout is installed unchanged
  # under share/blackhole, Dockerfile included, and the daemon reads it straight
  # out of the store; nothing writes back into ROOT_DIR, which is what makes a
  # read-only path workable.
  version ? "0-unstable-2026-11-11",
  rev ? "49e27ed949384b69b07c1bb52c43ce5cd3e145ba",
  hash ? "sha256-qCO0WuL3P3dT02nxe0nuLe5xpgwLO2sssBcfNnlI07M=",
}:

stdenv.mkDerivation {
  pname = "blackhole";
  inherit version;

  src = fetchFromGitHub {
    owner = "tommy0103";
    repo = "blackhole";
    inherit rev hash;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  dontConfigure = true;
  # The tree is not all host-side: the Dockerfile COPYs docker-entrypoint.sh and
  # the statusline/session-hook scripts into a Debian image, where a rewritten
  # /nix/store shebang would not exist. Only bin/blackhole runs here, so it is
  # the only file patched, by name, in installPhase.
  dontPatchShebangs = true;

  installPhase = ''
    runHook preInstall

    root=$out/share/blackhole
    mkdir -p "$root" "$out/bin"
    cp -r . "$root"

    # Only the host-side entry point is rewritten: every other script in the
    # tree is COPYed into the image by the Dockerfile and has to keep the
    # shebangs Debian resolves. shasum and the rest of the host tools come from
    # the wrapper's PATH, not from this patch.
    patchShebangs --host "$root/bin/blackhole"

    makeWrapper "$root/bin/blackhole" "$out/bin/blackhole" \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
          findutils
          gawk
          gnugrep
          gnused
          perl
          procps
          util-linux
        ]
      }

    # `blackhole install` is what upstream's install step runs, and what
    # `blackhole status` checks for; Nix owns the profile instead, so the same
    # two names come from here and `install` stays unused.
    ln -s blackhole "$out/bin/claude"

    runHook postInstall
  '';

  meta = {
    description = "Run Claude Code in a Linux container with only the current project mounted";
    homepage = "https://github.com/tommy0103/blackhole";
    license = lib.licenses.mit;
    mainProgram = "blackhole";
    platforms = lib.platforms.linux;
  };
}

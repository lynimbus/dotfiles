{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
  # The newest version is announced by core/latest.json; "just bump herdr-core"
  # hands it to nix-update, which rewrites this version and the hash of the
  # archive at core/<version>/ together.
  version ? "0.1.20",
  hash ? "sha256-rGuGiQxFGjdYRiCqpDi3G8DQvUMKLnwdfglfBSxBTnQ=",
}:

stdenvNoCC.mkDerivation {
  pname = "herdr-core";
  inherit version;

  # Upstream publishes one static ELF per target (Linux builds are static, so
  # no patchelf or nix-ld involvement). The archive holds herdr-core plus
  # LICENSE and THIRD-PARTY-NOTICES; upstream's install.sh puts the binary on
  # PATH as both `herdr-core` and `hc`.
  #
  # --build is what bump-packages.sh asks for on a release-asset package: a
  # fetchurl src carries no rev, so nix-update re-fetches on every run and only
  # the build proves the new hash and the version check.
  src = fetchurl {
    url = "https://releases.herdr.dev/core/${version}/herdr-core-linux-x86_64.tar.gz";
    inherit hash;
  };

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 herdr-core $out/bin/herdr-core
    ln -s herdr-core $out/bin/hc
    install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/doc/herdr-core
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  # releases.herdr.dev is not a forge nix-update can enumerate releases from,
  # so the version comes from the release manifest instead. nix-update gets it
  # as a fixed --version and still derives src.hash by fetching the new URL.
  passthru.bump = [
    "--build"
    "--bump-manifest=https://releases.herdr.dev/core/latest.json"
  ];

  meta = {
    description = "Terminals for coding agents that stay alive after you leave (hc)";
    homepage = "https://herdr.dev/core";
    changelog = "https://github.com/herdrdev/herdr-core/releases/tag/v${version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "hc";
  };
}

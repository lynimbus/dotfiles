{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
  # The version and the archive hash come from the same release tag;
  # "just bump antigravity-cli" (nix-update) rewrites these literals together.
  # nixpkgs carries this package too, but its version trails upstream's latest
  # release, and overlay.nix replaces the nixpkgs attribute in place.
  version ? "1.5.6",
  hash ? "sha256-dZQC5bujWTjhRxC31PFBOv2CxbTtxzwjKHeEzkf356Q=",
}:

stdenvNoCC.mkDerivation {
  pname = "antigravity-cli";
  inherit version;

  # Upstream publishes the same build three ways. The glibc asset is a
  # dynamically linked ELF that needs patchelf against the store; the musl asset
  # is one static ELF that runs as it is. The archive holds a single file named
  # antigravity, which upstream's install.sh puts on PATH as agy.
  #
  # --build is what bump-packages.sh asks for on a release-asset package: a
  # fetchurl src carries no rev, so nix-update re-fetches on every run and only
  # the build proves the new hash and the version check.
  src = fetchurl {
    url = "https://github.com/google-antigravity/antigravity-cli/releases/download/${version}/agy_cli_linux_x64_musl.tar.gz";
    inherit hash;
  };

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 antigravity $out/bin/agy
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.bump = [ "--build" ];

  meta = {
    description = "Google's terminal agent client for Antigravity";
    homepage = "https://antigravity.google/product/antigravity-cli";
    changelog = "https://github.com/google-antigravity/antigravity-cli/releases/tag/${version}";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "agy";
  };
}

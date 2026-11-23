{
  lib,
  buildMyGoApp,
  fetchFromGitHub,
  fetchurl,
  versionCheckHook,
  # The release archive supplies fonts, icons, kero.desktop, and libghostty-vt.so.
  # `just bump kero` (nix-update --custom-dep tarball) moves all hashes together.
  version ? "2.1.36",
  hash ? "sha256-JSJ4u76cEjiHf9UMvQk+Ey5y3K3a1T6o71o+mz0crS8=",
  archiveSuffix ? "linux-amd64",
  archiveHash ? "sha256-axNwftgYlgqycxtiLBpTv0EI5ZZ8/w9c9U6I/i0e6Ho=",
  vendorHash ? "sha256-F8xtFCh48EVyLIBJAjORvbh15TFb7Kp6bm5UbC+bmKQ=",
}:

let
  tarball = fetchurl {
    url = "https://github.com/egoist/kero/releases/download/v${version}/kero-${version}-${archiveSuffix}.tar.gz";
    hash = archiveHash;
  };

  src = fetchFromGitHub {
    owner = "egoist";
    repo = "kero";
    tag = "v${version}";
    inherit hash;
  };
in
buildMyGoApp {
  pname = "kero";
  inherit
    version
    src
    vendorHash
    tarball
    ;
  packageName = "Kero";
  packageIdentifier = "sh.kero";
  tarballResources = [
    "fonts"
    "icon.png"
    "kero.png"
    "libghostty-vt.so"
  ];

  # Kero's unit tests require libghostty-vt.so and fonts beside the binary.
  doCheck = false;
  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Native terminal for coding agents, whose sessions outlive the window";
    homepage = "https://github.com/egoist/kero";
    changelog = "https://github.com/egoist/kero/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "kero";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryNativeCode
    ];
  };
}

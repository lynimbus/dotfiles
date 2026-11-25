{
  lib,
  buildMyGoApp,
  fetchFromGitHub,
  fetchurl,
  # The release archive supplies icons and mygo-music.desktop.
  # `just bump mygo-music` (nix-update --custom-dep tarball) moves all hashes together.
  version ? "0.1.26",
  hash ? "sha256-mZAOGMnOSLmxR61iEjt7pp0TosA0oBwMel9xvuQHyws=",
  archiveSuffix ? "linux-amd64",
  archiveHash ? "sha256-iy7D/U7xhP9vt/RhTdSPGQcap7j3U5LKiD87QpKl2kA=",
  vendorHash ? "sha256-CgAnPtjfDxOxjVvIG8zvMXwbrqjhF3spEqXEagQSIvE=",
}:

let
  tarball = fetchurl {
    url = "https://github.com/egoist/mygo-music/releases/download/v${version}/mygo-music-${version}-${archiveSuffix}.tar.gz";
    hash = archiveHash;
  };

  src = fetchFromGitHub {
    owner = "egoist";
    repo = "mygo-music";
    tag = "v${version}";
    inherit hash;
  };
in
buildMyGoApp {
  pname = "mygo-music";
  inherit
    version
    src
    vendorHash
    tarball
    ;
  packageName = "MyGo Music";
  packageIdentifier = "dev.egoist.music";
  tarballResources = [
    "icon.png"
    "mygo-music.png"
  ];

  # Tests play audio files and decode artwork; displaySmokeCheck covers the binary.
  doCheck = false;
  displaySmokeCheck = true;

  meta = {
    description = "Native music player for your own files and the streaming accounts you sign in to";
    homepage = "https://github.com/egoist/mygo-music";
    changelog = "https://github.com/egoist/mygo-music/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "mygo-music";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryNativeCode
    ];
  };
}

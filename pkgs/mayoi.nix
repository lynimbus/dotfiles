{
  lib,
  buildMyGoApp,
  fetchFromGitHub,
  fetchurl,
  # The release archive supplies icons, mayoi.desktop, and libghostty-vt.so.
  # `just bump mayoi` (nix-update --custom-dep tarball) moves all hashes together.
  version ? "0.23.5",
  hash ? "sha256-B5+1vnGE3uJua09fDmnBF19Fwg/VKo1YJgbryBy9Oyk=",
  archiveSuffix ? "linux-amd64",
  archiveHash ? "sha256-dAOMEvyESdYV9/xSJlhF98JBZQYL0dndZqiEmKN1IDc=",
  vendorHash ? "sha256-JVgp+X+k0KG+poaejlsSR27Ci2eppboEFF1lORkMDYM=",
}:

let
  tarball = fetchurl {
    url = "https://github.com/sorrycc/Mayoi/releases/download/v${version}/mayoi-${version}-${archiveSuffix}.tar.gz";
    hash = archiveHash;
  };

  src = fetchFromGitHub {
    owner = "sorrycc";
    repo = "Mayoi";
    tag = "v${version}";
    inherit hash;
  };
in
buildMyGoApp {
  pname = "mayoi";
  inherit
    version
    src
    vendorHash
    tarball
    ;
  subPackages = [ "./cmd/mayoi" ];
  packageName = "Mayoi";
  packageIdentifier = "dev.mayoi.editor";
  tarballResources = [
    "icon.png"
    "mayoi.png"
    "libghostty-vt.so"
  ];

  # Tests open windows and load libghostty-vt.so; displaySmokeCheck covers the binary.
  doCheck = false;
  displaySmokeCheck = true;

  meta = {
    description = "Code editor that draws its own UI on the GPU, with tabs, splits, plugins and a Vim mode";
    homepage = "https://github.com/sorrycc/Mayoi";
    changelog = "https://github.com/sorrycc/Mayoi/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "mayoi";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryNativeCode
    ];
  };
}

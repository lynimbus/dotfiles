{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  fcitx5,
  curl,
  nlohmann_json,
}:

stdenv.mkDerivation {
  pname = "fcitx5-hymt-translate";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./fcitx5-hymt-translate;
    fileset = ./fcitx5-hymt-translate;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];

  buildInputs = [
    fcitx5
    curl
    nlohmann_json
  ];

  doCheck = true;

  passthru.bump = null;

  meta = {
    description = "Fcitx5 C++ addon for async Chinese-to-English translation via Hy-MT2-1.8B and llama.cpp";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

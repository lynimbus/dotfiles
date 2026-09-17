{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  libgcc,
  alsa-lib,
  glib,
  wayland,
  libxkbcommon,
  libdrm,
  libglvnd,
  mesa,
  libxrandr,
  libva,
}:

let
  ver = "1.18.0";
  zipHash = "sha256-G1Jl0/eXyv6zPi7Tywog9eGXogTpCEidZDGgm6JqNPc=";
in
stdenv.mkDerivation {
  pname = "zed-prebuilt";
  version = ver;

  src = fetchzip {
    url = "https://github.com/zed-industries/zed/releases/download/v${ver}/zed-linux-x86_64.tar.gz";
    hash = zipHash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    libgcc
    alsa-lib
    glib
    wayland
    libxkbcommon
    libdrm
    libglvnd
    mesa
    libxrandr
    libva
  ];

  runtimeDependencies = [
    glib
    wayland
    libxkbcommon
    libdrm
    libglvnd
    mesa
    libxrandr
    libva
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    if [ -d zed-linux-x86_64 ]; then
      cp -r zed-linux-x86_64/. "$out/"
    else
      cp -r . "$out/"
    fi
    ln -s "$out/bin/zed" "$out/bin/zeditor"
    runHook postInstall
  '';

  meta = {
    mainProgram = "zed";
    description = "Zed editor (official prebuilt v${ver})";
    homepage = "https://zed.dev";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}

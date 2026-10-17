{
  lib,
  stdenv,
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
  src,
}:

let
  # The bundle carries no version metadata, so derive it from what `nix flake
  # update` locked. The URL is a rolling "preview/latest" redirect, so several
  # builds can share a day; minute precision keeps them distinguishable.
  version =
    let
      stamp = src.lastModifiedDate or (toString (src.lastModified or 0));
    in
    "preview-${builtins.substring 0 12 stamp}";
in
stdenv.mkDerivation {
  pname = "zed-prebuilt";
  inherit version src;

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
    cp -r . "$out/"
    runHook postInstall
  '';

  meta = {
    mainProgram = "zed";
    description = "Zed editor (official preview build)";
    homepage = "https://zed.dev";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}

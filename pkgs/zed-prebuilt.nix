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

stdenv.mkDerivation (finalAttrs: {
  pname = "zed-i18n-prebuilt";
  version = "1.20.2-i18n.2";

  src = fetchzip {
    url = "https://github.com/LI-NA/zed-i18n/releases/download/v${finalAttrs.version}/zed-i18n-linux-x86_64.tar.gz";
    hash = "sha256-K4YrP6+TCBdL7TkS7ynHXpJvDhyptby2vzzxe4AAC+g=";
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
    cp -r . "$out/"
    ln -s "$out/bin/zed" "$out/bin/zeditor"
    runHook postInstall
  '';

  meta = {
    mainProgram = "zed";
    description = "Zed editor (zed-i18n community-localized prebuilt v${finalAttrs.version})";
    homepage = "https://github.com/LI-NA/zed-i18n";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
})

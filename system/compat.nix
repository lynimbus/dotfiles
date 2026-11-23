{ pkgs, ... }:

{
  # Prebuilt ELF binaries aimed at a generic Linux — the Android SDK tools,
  # anything pi-lens installs into its managed-tools directory — request the
  # FHS interpreter /lib64/ld-linux-x86-64.so.2, which on NixOS is a stub
  # that only prints an explanation and refuses to run them. nix-ld replaces
  # that stub with a shim that loads the binary against the Nix glibc and a
  # broad default library set (zlib, openssl, curl, libstdc++, ...), so such
  # binaries run without a per-binary patchelf or an FHS sandbox.
  programs.nix-ld = {
    enable = true;

    # The default set covers the interpreter and a generic glibc toolchain, and
    # nothing else. Prebuilt games and GUI binaries additionally link the
    # graphics and multimedia stack, which is what this list adds.
    libraries = with pkgs; [
      SDL2
      SDL2_image
      SDL2_mixer
      SDL2_ttf
      libGL
      libGLU
      vulkan-loader
      libxkbcommon
      freetype
      fontconfig
      libpng
      libjpeg
      icu
      sqlite
      libX11
      libXext
      libXrandr
      libXi
      libXcursor
      libpulseaudio
      alsa-lib
    ];
  };

  # Mount /usr/bin (and bind /bin) as a FUSE view of the calling process PATH
  # so generic #!/usr/bin/* shebang scripts resolve without patching.
  services.envfs.enable = true;

  # AppImage runner for programs that ship their own complete root; steam-run
  # is provided by programs.steam in system/gaming.nix.
  environment.systemPackages = with pkgs; [
    appimage-run
  ];
}

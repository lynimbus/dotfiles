{ ... }:

{
  # Prebuilt ELF binaries aimed at a generic Linux — the Android SDK tools,
  # anything pi-lens installs into its managed-tools directory — request the
  # FHS interpreter /lib64/ld-linux-x86-64.so.2, which on NixOS is a stub
  # that only prints an explanation and refuses to run them. nix-ld replaces
  # that stub with a shim that loads the binary against the Nix glibc and a
  # broad default library set (zlib, openssl, curl, libstdc++, ...), so such
  # binaries run without a per-binary patchelf or an FHS sandbox.
  programs.nix-ld.enable = true;
}

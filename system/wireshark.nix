{ username, ... }:

{
  # Capture needs a kernel capability that can only be attached where the wrapper
  # is installed, so this half lives at the system level and not in
  # home/packages.nix: dumpcap arrives with cap_net_raw,cap_net_admin for the
  # wireshark group, and tshark is patched to run whichever dumpcap it finds
  # first on PATH, which is /run/wrappers/bin.
  #
  # The package is wireshark-cli rather than wireshark: tshark for scripts and
  # termshark for the TUI are what this configuration drives, and the Qt
  # frontend would only add a GUI dependency tree on top of them.
  programs.wireshark.enable = true;

  # The module creates the group and the wrapper but puts nobody in the group.
  # A list option, so this concatenates with system/users.nix rather than
  # replacing it.
  users.users.${username}.extraGroups = [ "wireshark" ];
}

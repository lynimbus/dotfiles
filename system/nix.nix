{
  inputs,
  lib,
  repoRoot,
  username,
  ...
}:

{
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  nixpkgs.config.allowUnfree = true;

  # pkgs/nsh-android-sdk composes the SDK from Google's unfree packages; this
  # accepts their license the way androidenv reads it (the same acceptance
  # is in flake.nix's legacyPackages import, so `nix build .#nsh` paths agree
  # with the system's).
  nixpkgs.config.android_sdk.accept_license = true;

  documentation.nixos.enable = false;

  programs.nh = {
    enable = true;
    flake = repoRoot;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = lib.mkForce [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.bfsu.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
      "https://rxda-cache.cachix.org"
      "https://cache.numtide.com"
      "https://noctalia.cachix.org"
      "https://umbriel.cachix.org"
      # system/boot.nix takes its kernel from xddxdd/nix-cachyos-kernel, whose
      # Hydra pushes the compiled kernels here. Without this entry the LTO
      # kernel is a multi-hour local build.
      "https://cache.lantian.pub/lantian"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "rxda-cache.cachix.org-1:LDGrYaB+dF7wh+uWMLjh5VsckzFnnCyGkMH1sKHN++g="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "umbriel.cachix.org-1:JfNq/2yg2S6D6z4Z2dVSZrZlDPQTKtexB6GAVLD98nw="
      "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
    ];
    download-buffer-size = 524288000;
    auto-optimise-store = true;
    warn-dirty = false;

    # This machine has 16 threads and 22G of memory. Letting Nix run every job
    # with every core oversubscribes both and makes a large build swap, so cap
    # the product at the thread count: 2 jobs of 8 cores each gives a single
    # heavy Rust/C++ build half the machine's threads instead of stalling at 2.
    max-jobs = 2;
    cores = 8;

    # Expose the host's sccache directory to sandboxed builds (the trailing `?`
    # keeps builds working even before systemd-tmpfiles creates it).
    extra-sandbox-paths = [
      "/var/cache/sccache?"
    ];
  };

  # Share /var/cache/sccache between Nix's nixbld workers and the host user via
  # setgid + default POSIX ACLs so files created by any UID stay writable by all.
  systemd.tmpfiles.rules = [
    "d /var/cache/sccache 2770 root nixbld -"
    "a+ /var/cache/sccache - - - - u:${username}:rwx,g:nixbld:rwx,m::rwx,d:u:${username}:rwx,d:g:nixbld:rwx,d:m::rwx"
  ];

  # The daemon lowers its own scheduling class so a build cannot starve the
  # session you are typing in. "batch" over "idle" keeps rebuilds from being
  # starved in turn, which matters because a rebuild is how the system gets
  # fixed.
  nix.daemonCPUSchedPolicy = "batch";
  nix.daemonIOSchedClass = "best-effort";
  nix.daemonIOSchedPriority = 6;

  # auto-optimise-store only deduplicates what it writes from now on, so a store
  # that has been growing for months keeps the duplicates it already has. This
  # schedules the full pass instead of leaving it to a manual `just gc`.
  nix.optimise = {
    automatic = true;
    dates = [ "03:45" ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    persistent = true;
    options = "--delete-older-than 3d";
  };
}

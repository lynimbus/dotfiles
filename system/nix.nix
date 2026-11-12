{
  inputs,
  lib,
  repoRoot,
  ...
}:

{
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  nixpkgs.config.allowUnfree = true;

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
      "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
    ];
    download-buffer-size = 524288000;
    auto-optimise-store = true;
    warn-dirty = false;

    # This machine has 16 threads and 22G of memory. Letting Nix run every job
    # with every core oversubscribes both and makes a large build swap, so cap
    # the product at the thread count: 8 jobs of 2 cores each.
    max-jobs = 8;
    cores = 2;
  };

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

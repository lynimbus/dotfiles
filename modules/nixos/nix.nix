{ inputs, pkgs, ... }:

{
  # 让裸 `nix run nixpkgs#<pkg>` / `nix shell nixpkgs#...` 使用本 flake 锁定的 nixpkgs,
  # 而不是 nix 内置的 github:NixOS/nixpkgs master 映射。
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  # 内存压缩交换:22G 内存无 swap 文件时的安全网,平时几乎不占内存。
  zramSwap.enable = true;

  # 省去生成 NixOS 手册(man configuration.nix 等),加快 rebuild。
  documentation.nixos.enable = false;

  nixpkgs.config.allowUnfree = true;

  programs.nh = {
    enable = true;
    flake = "/home/lynimbus/dotfiles";
  };

  environment.systemPackages = with pkgs; [
    neovim
    curl
    wget
    git
    xwayland-satellite
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # 清华镜像优先（内容与密钥同 cache.nixos.org，国内提速），官方兜底。
    substituters = [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
    # 系统层声明二进制缓存：flake.nix 的 nixConfig 只对 trusted-users 生效，
    # 而 trusted-users 只有 root，写在这里才对普通用户的 nix build 也生效。
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://deepseek-harness-nix.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CXWu8iE8f2b24L2pY="
      "deepseek-harness-nix.cachix.org-1:5NrkwLN9veNMhiINtU5ZeV4isXFhFsOwn6Ms7J1M+TA="
    ];
    # 下载缓冲加大（旧配置沿用，大包下载更快）
    download-buffer-size = 524288000;
    auto-optimise-store = true;
    warn-dirty = false;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

}

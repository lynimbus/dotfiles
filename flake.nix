{
  description = "lynimbus's nixos flake configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    linuxqq-wayland-fix = {
      url = "github:SHORiN-KiWATA/linuxqq-wayland-fix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-style-plymouth = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    umbriel.url = "github:noctalia-dev/umbriel/cachix";

    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    noctalia-greeter.url = "github:noctalia-dev/noctalia-greeter/cachix";

    luciole.url = "github:noctalia-dev/luciole/cachix";

    # system/comma.nix uses the comma wrapper that carries a prebuilt nix-index
    # database, so ", foo" resolves a program name without building an index.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # system/boot.nix takes its kernel from here. The `release` branch is the one
    # this project builds on its own Hydra and pushes to the cache in
    # system/nix.nix, so the kernel downloads instead of compiling. Its nixpkgs
    # input is deliberately not followed: the kernel patches and the cached
    # builds both assume the revision this flake pins.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    crane.url = "github:ipetkov/crane";

    magpie-releases = {
      url = "github:yetone/magpie-releases";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pi = {
      url = "github:earendil-works/pi";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    t3code-jj = {
      url = "github:lynimbus/t3code-jj";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      hostname = "nixos";
      username = "lynimbus";
      email = "128837704+lynimbus@users.noreply.github.com";

      homeDirectory = "/home/${username}";
      repoRoot = "${homeDirectory}/dotfiles";

      sshKey = "${homeDirectory}/.ssh/id_ed25519";

      # Shared across overlay.nix (Crane builds), system/nix.nix (Nix sandbox
      # mount + tmpfiles ACLs), and home/programs/rust.nix (Cargo wrapper).
      sccache = {
        dir = "/var/cache/sccache";
        cacheSize = "20G";
      };

      local = import ./overlay.nix {
        inherit repoRoot sccache;
        lib = nixpkgs.lib;
        crane = inputs.crane;
      };

      # Single source of truth for nixpkgs config and overlays shared between
      # legacyPackages/packages (fast per-package eval and nix-update) and the
      # NixOS module fixpoint.
      nixpkgsConfig = {
        allowUnfree = true;
        android_sdk.accept_license = true;
      };

      overlays = [
        local.overlay
        inputs.magpie-releases.overlays.default
        inputs.pi.overlays.default
      ];

      pkgs = import nixpkgs {
        inherit system overlays;
        config = nixpkgsConfig;
      };

      # One set of arguments for the system and the home modules, so a value
      # reaches whichever module needs it without a second list to maintain.
      moduleArgs = {
        inherit
          inputs
          hostname
          username
          email
          homeDirectory
          repoRoot
          sshKey
          sccache
          ;
      };
    in
    {
      # Direct local packages so `nix build .#<pkg>` works for any derivation in
      # pkgs/ (excluding non-derivation compositions such as nsh-android-sdk).
      packages.${system} = nixpkgs.lib.filterAttrs (_: nixpkgs.lib.isDerivation) (
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value = pkgs.${name};
          }) local.names
        )
      );

      # nix-update rewrites a package through this attribute path, and
      # `nix build .#legacyPackages.${system}.<pkg>` builds one package on its
      # own without evaluating the full NixOS module fixpoint.
      legacyPackages.${system} = pkgs // {
        # Per package, the nix-update flags its file declares in passthru.bump,
        # or null for a package that does not track a release of its own.
        # scripts/bump-packages.sh reads this, so adding a package never means
        # editing the script.
        bumpMatrix = builtins.listToAttrs (
          map (name: {
            inherit name;
            value = pkgs.${name}.passthru.bump or null;
          }) local.names
        );
      };

      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = moduleArgs;
        modules = [
          {
            nixpkgs = {
              config = nixpkgsConfig;
              inherit overlays;
            };
          }
          inputs.nixos-hardware.nixosModules.mechrevo-gm5hg0a
          inputs.mangowm.nixosModules.mango
          inputs.umbriel.nixosModules.default
          inputs.noctalia.nixosModules.default
          inputs.noctalia-greeter.nixosModules.default
          inputs.linuxqq-wayland-fix.nixosModules.default
          ./system/init.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = moduleArgs;
            home-manager.users.${username} = ./home/init.nix;
            home-manager.backupFileExtension = "old";
            home-manager.overwriteBackup = true;
          }
        ];
      };

      checks.${system} =
        let
          pkgDerivations = self.packages.${system};
          invariantFailures = builtins.concatMap (
            name:
            let
              drv = pkgDerivations.${name};
              bump = drv.passthru.bump or null;
              src = drv.src or null;
              isFetchUrl = src != null && (src ? url) && !(src ? rev) && !(src ? tag);
              pos = (drv.meta or { }).position or "";
              expectedPos = "/pkgs/${name}.nix:";
            in
            nixpkgs.lib.optional ((drv.pname or drv.name or "") == "") "${name}: missing pname/name"
            ++ nixpkgs.lib.optional (
              (drv.version or null) != null && (drv.pname or "") == ""
            ) "${name}: versioned derivation must set pname"
            ++ nixpkgs.lib.optional (
              ((drv.meta or { }).description or "") == ""
            ) "${name}: missing meta.description"
            ++ nixpkgs.lib.optional (
              bump != null && !(nixpkgs.lib.hasInfix expectedPos pos)
            ) "${name}: meta.position (${pos}) must point into pkgs/${name}.nix for nix-update"
            ++ nixpkgs.lib.optional (
              bump != null && isFetchUrl && !(builtins.elem "--build" bump)
            ) "${name}: fetchurl package with passthru.bump must include \"--build\""
          ) (builtins.attrNames pkgDerivations);
        in
        {
          formatting = pkgs.runCommandLocal "check-formatting" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            find ${self} -name '*.nix' -print0 | xargs -0 nixfmt --check
            touch $out
          '';

          shellcheck = pkgs.runCommandLocal "check-shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            cd ${self}
            find scripts pkgs home -name '*.sh' -print0 | xargs -0 shellcheck
            touch $out
          '';

          pkg-invariants = pkgs.runCommandLocal "check-pkg-invariants" { } (
            if invariantFailures == [ ] then
              "touch $out"
            else
              ''
                cat >&2 <<'EOF'
                Package invariant check failed:
                ${nixpkgs.lib.concatStringsSep "\n" invariantFailures}
                EOF
                exit 1
              ''
          );

          overview = pkgs.overview;
        };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}

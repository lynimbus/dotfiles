{
  description = "lynimbus's nixos flake configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyclipsync = {
      url = "github:ryan4yin/pyclipsync/v0.1.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-style-plymouth = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";

    pi-main = {
      url = "github:earendil-works/pi";
      flake = false;
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

      pkgs = nixpkgs.legacyPackages.${system};

      mkLocalPkgs = p: {
        zed-editor = p.callPackage ./pkgs/zed-prebuilt.nix { };
        qingjian = p.callPackage ./pkgs/qingjian/package.nix { };
        pi-coding-agent = p.callPackage ./pkgs/pi-main.nix { src = inputs.pi-main; };
      };

      localOverlay = final: _prev: mkLocalPkgs final;
    in
    {
      packages.${system} = mkLocalPkgs pkgs;

      apps.${system}.update-pkgs =
        let
          script = pkgs.writeShellApplication {
            name = "update-pkgs";
            runtimeInputs = [
              pkgs.nix-update
              pkgs.git
              pkgs.nix
              pkgs.gh
              pkgs.gnugrep
              pkgs.gnused
              pkgs.jq
              pkgs.prefetch-npm-deps
              pkgs.coreutils
            ];
            text = ''
              update_pi() (
                tmpdir=$(mktemp -d)
                cp flake.lock "$tmpdir/flake.lock"
                cp pkgs/pi-main.nix "$tmpdir/pi-main.nix"

                # shellcheck disable=SC2329
                restore_pi() {
                  cp "$tmpdir/flake.lock" flake.lock
                  cp "$tmpdir/pi-main.nix" pkgs/pi-main.nix
                }

                # shellcheck disable=SC2154
                trap 'status=$?; if [ "$status" -ne 0 ]; then restore_pi; fi; rm -rf "$tmpdir"; exit "$status"' EXIT

                current=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.pi-main.rev')
                # just update may have changed flake.lock before this app runs.
                lock_was_dirty=false
                if ! git diff --quiet HEAD -- flake.lock; then
                  lock_was_dirty=true
                fi
                nix flake update pi-main
                latest=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.pi-main.rev')
                if [ "$current" = "$latest" ] && [ "$lock_was_dirty" = false ]; then
                  echo "pi-main: already up to date ($current)"
                  return
                fi

                src=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.pi-main')
                version=$(jq -r .version "$src/packages/coding-agent/package.json")
                npm_deps_hash=$(prefetch-npm-deps "$src/package-lock.json")
                model_data_hash=$(nix store prefetch-file --json --hash-type sha256 \
                  "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-$version.tgz" \
                  | jq -r .hash)

                sed -i \
                  -e "s|^  npmDepsHash = .*|  npmDepsHash = \"$npm_deps_hash\";|" \
                  -e "s|^    hash = .*|    hash = \"$model_data_hash\";|" \
                  pkgs/pi-main.nix

                nix build .#pi-coding-agent --no-link
                echo "pi-main: updated $current -> $latest (pi $version)"
              )
              update_pi

              current=$(nix eval --raw .#zed-editor.version)
              latest=$(gh release view --repo LI-NA/zed-i18n --json tagName --jq '.tagName | sub("^v"; "")')
              if [ "$current" = "$latest" ]; then
                echo "zed-editor: already up to date ($current)"
              else
                echo "zed-editor: updating $current -> $latest"
                nix-update --flake --version-regex '^v?(\d+\.\d+\.\d+-i18n\.\d+)$' zed-editor
              fi

              current=$(nix eval --raw .#qingjian.src.rev)
              latest=$(gh api repos/qingjian-team/qingjian/commits/HEAD --jq .sha)
              if [ "$current" = "$latest" ]; then
                echo "qingjian: already up to date ($current)"
              else
                # shellcheck disable=SC2016
                grep -qF 'version = "0.1.3-unstable-''${lib.substring 0 8 rev}"' pkgs/qingjian/package.nix \
                  || { echo "qingjian: version no longer derives from rev, refusing to auto-update" >&2; exit 1; }
                echo "qingjian: updating $current -> $latest"
                nix-update --flake --version=branch qingjian
              fi
            '';
          };
        in
        {
          type = "app";
          program = "${script}/bin/update-pkgs";
        };
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs hostname username; };
        modules = [
          {
            nixpkgs.overlays = [ localOverlay ];
          }
          inputs.nixos-hardware.nixosModules.mechrevo-gm5hg0a
          ./system/init.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs username email; };
            home-manager.users.${username} = ./home/init.nix;
            home-manager.backupFileExtension = "old";
          }
        ];
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}

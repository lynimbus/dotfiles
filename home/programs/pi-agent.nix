{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
{
  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.pi-coding-agent;
    context = ../pi-agent/AGENTS.md;
    extraPackages = [
      pkgs.nodejs
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.qmd
    ];
    # Magpie owns the writable provider catalog and model selection.
    settings = { };
    models = { };
  };
  home.packages = [ pkgs.magpie ];

  # Keep a stable, user-writable entry point for Magpie's own updater and
  # autostart record. The actual binary lives under XDG_DATA_HOME and is
  # seeded by the FHS launcher on first use.
  home.file.".local/bin/magpie".source = "${pkgs.magpie}/bin/magpie";
  home.file.".local/share/applications/magpie.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Magpie
    Comment=Every agent's model. One place.
    Exec=${config.home.homeDirectory}/.local/bin/magpie %u
    Icon=applications-development
    Categories=Development;Utility;
    MimeType=x-scheme-handler/magpie;
    Terminal=false
  '';

  # Magpie owns its GUI, gateway and XDG autostart entry. Migrate the old
  # Nix-managed gateway once, then leave the app's startup preference alone.
  # systemd's XDG autostart generator turns that file into a user service.
  home.activation.magpieAutostart = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    marker="$HOME/.local/state/magpie/nix-autostart-initialized"
    if [ ! -e "$marker" ]; then
      systemctl --user disable --now magpie-gateway.service >/dev/null 2>&1 || true
      if [ ! -e "$HOME/.config/autostart/magpie.desktop" ]; then
        run ${pkgs.magpie}/bin/magpie autostart on
      fi
      run mkdir -p "$(dirname "$marker")"
      run touch "$marker"
    fi
  '';
  # Detach before linkGeneration removes obsolete Home Manager links.
  # Preserve non-model preferences and never touch auth.json.
  home.activation.detachPiMagpieConfig =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
      ''
        pi_dir="$HOME/.pi/agent"
        run mkdir -p "$pi_dir"
        for file in settings.json models.json; do
          path="$pi_dir/$file"
          if [ -L "$path" ]; then
            tmp="$path.tmp.$$"
            case "$(readlink "$path")" in
              /nix/store/*)
                run install -m 0600 "$path" "$tmp"
                run mv -T "$tmp" "$path"
                ;;
            esac
          fi
        done
      '';
}

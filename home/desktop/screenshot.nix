{ pkgs, ... }:

{
  # The pipeline lives here rather than in a repo script: grim, slurp, satty and
  # wl-clipboard are this one command's runtime inputs, and splitting the tool
  # list from the command that needs it is how the two drift apart.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "screenshot";
      runtimeInputs = with pkgs; [
        grim
        slurp
        satty
        wl-clipboard
        xdg-user-dirs
      ];
      text = ''
        grim -t ppm -g "$(slurp -o -d -F monospace)" - |
          satty \
            --filename - \
            --copy-command=wl-copy \
            --annotation-size-factor 2.0 \
            --output-filename="$(xdg-user-dir PICTURES)/Screenshots/Screenshot from %Y-%m-%d %H:%M:%S.png" \
            --actions-on-enter="save-to-clipboard,exit" \
            --brush-smooth-history-size=5 \
            --disable-notifications
      '';
    })
  ];
}

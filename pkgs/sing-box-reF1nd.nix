{ symlinkJoin, package }:
symlinkJoin {
  name = "sing-box-reF1nd";
  paths = [ package ];
  postBuild = ''
    mv "$out/bin/sing-box" "$out/bin/sing-box-reF1nd"
    rm -rf "$out/share" "$out/lib/systemd"
  '';
}

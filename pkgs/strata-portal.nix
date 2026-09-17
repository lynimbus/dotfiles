{
  lib,
  runCommand,
  strata,
}:

runCommand "strata-portal-${strata.version}"
  {
    meta = {
      description = "Opt-in FileChooser portal registration for Strata";
      inherit (strata.meta) platforms;
      license = lib.licenses.mit;
    };
  }
  ''
    install -Dm644 ${strata}/share/xdg-desktop-portal/portals/strata.portal \
      "$out/share/xdg-desktop-portal/portals/strata.portal"
    install -Dm644 ${strata}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service \
      "$out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service"
  ''

{
  lib,
  runCommand,
  strata,
}:

runCommand "strata-file-manager-${strata.version}"
  {
    meta = {
      description = "D-Bus activation for org.freedesktop.FileManager1 provided by Strata";
      inherit (strata.meta) platforms;
      license = lib.licenses.mit;
    };
  }
  ''
    install -Dm644 ${strata}/share/strata/io.github.lgse.Strata.FileManager1.service \
      "$out/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service"
  ''

{
  bun,
  lib,
  makeWrapper,
  symlinkJoin,
  upstream,
}:

symlinkJoin {
  name = "${upstream.name}-wrapped";
  paths = [ upstream ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/magpie --set-default MAGPIE_BUN ${lib.getExe bun}
  '';
  meta = upstream.meta;
  passthru = (upstream.passthru or { }) // {
    inherit upstream;
  };
}

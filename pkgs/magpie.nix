{
  bun,
  lib,
  makeWrapper,
  rtk,
  symlinkJoin,
  upstream,
}:

symlinkJoin {
  name = "${upstream.name}-wrapped";
  paths = [ upstream ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/magpie \
      --set-default MAGPIE_BUN ${lib.getExe bun} \
      --prefix PATH : ${lib.makeBinPath [ rtk ]}
  '';
  meta = upstream.meta;
  passthru = (upstream.passthru or { }) // {
    inherit upstream;
  };
}

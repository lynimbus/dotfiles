{
  lib,
  magpie,
  makeWrapper,
  rtk,
  symlinkJoin,
}:
symlinkJoin {
  name = "${magpie.name}-rtk";
  paths = [ magpie ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/magpie \
      --prefix PATH : ${lib.makeBinPath [ rtk ]} \
      --set MAGPIE_SELF $out/bin/magpie
  '';
  meta = magpie.meta;
}

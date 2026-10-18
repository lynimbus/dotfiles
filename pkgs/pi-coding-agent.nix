{
  lib,
  stdenv,
  makeWrapper,
  nodejs_22,
  pi-agent-desktop,
  fd,
  ripgrep,
  rtk,
}:

let
  server = "${pi-agent-desktop}/lib/Pi Agent/resources/server";
  upstream = "${server}/node_modules/@earendil-works/pi-coding-agent";
in
stdenv.mkDerivation {
  pname = "pi-coding-agent";
  inherit (lib.importJSON "${upstream}/package.json") version;

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib
    ln -s ${lib.escapeShellArg "${upstream}/dist/bundle/cli.js"} $out/lib/pi-cli.js

    makeWrapper ${lib.getExe nodejs_22} $out/bin/pi \
      --add-flags $out/lib/pi-cli.js \
      --prefix NODE_PATH : ${lib.escapeShellArg "${server}/node_modules"} \
      --prefix PATH : ${
        lib.makeBinPath [
          fd
          ripgrep
          rtk
        ]
      } \
      --set-default PI_SKIP_VERSION_CHECK 1

    runHook postInstall
  '';

  meta = {
    description = "pi coding agent CLI, taken from the pi-agent-desktop build it ships with";
    homepage = "https://pi.dev/";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = [ "x86_64-linux" ];
  };
}

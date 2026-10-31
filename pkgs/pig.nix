{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  nodejs_22,
  fd,
  ripgrep,
  rtk,
  # The release tarball is the only source: the version and its hash name it
  # both, and `just bump pig` (nix-update) moves the two literals to the
  # latest release together.
  version ? "0.5.3",
  hash ? "sha256-HkXl5ZGgbQh1h9XwnSttYWc6HiYssmCeYYne//1a5+w=",
  archiveSuffix ? "linux-amd64",
}:

let
  runtimePath = lib.makeBinPath [
    nodejs_22
    fd
    ripgrep
    rtk
  ];
in
stdenv.mkDerivation {
  pname = "pig";
  inherit version;

  src = fetchurl {
    url = "https://github.com/MichaelKinsy/PiG/releases/download/v${version}/pig-${version}-${archiveSuffix}.tar.gz";
    inherit hash;
  };

  sourceRoot = "pig-${version}-${archiveSuffix}";

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # The release ships one statically linked binary beside the licence texts
    # of the Go modules it links: there is nothing to patch and nothing to
    # build, only to place.
    install -Dm755 pig $out/bin/pig
    install -Dm644 LICENSE $out/share/licenses/pig/LICENSE
    install -Dm644 NOTICE $out/share/licenses/pig/NOTICE
    install -Dm644 THIRD_PARTY_NOTICES.md $out/share/licenses/pig/THIRD_PARTY_NOTICES.md
    cp -r LICENSES $out/share/licenses/pig/LICENSES

    runHook postInstall
  '';

  # PiG runs Pi's TypeScript extensions in a Node subprocess, so node is not
  # optional here: every package declared in settings.json is TypeScript. fd
  # and ripgrep answer the tools' file searches before PiG downloads its own
  # copy of either into the agent directory, and rtk shrinks command output
  # before the model reads it. The version check reaches the network to look
  # for an update a store path cannot take, so it stays off by default;
  # `pig update` still checks when run by hand.
  # This machine keeps the agent files in Pi's ~/.pi/agent, so PiG is told to
  # share them. It is a default of the wrapper and not a shell variable
  # because not every launch passes through a shell: Kero restores a saved
  # conversation by running `pi --session <id>` itself, and a shell-only
  # variable would leave that restore looking in ~/.pig.
  postFixup = ''
    wrapProgram $out/bin/pig \
      --prefix PATH : ${runtimePath} \
      --set-default PIG_USE_PI_DIRS 1 \
      --set-default PI_SKIP_VERSION_CHECK 1

    # Kero recognizes an agent pane by the name of its executable from a
    # fixed list that holds "pi" and not "pig", and restores a saved pi
    # conversation by running `pi --session <id>`. The alias keeps both
    # working: it is the same binary, and pig takes the same arguments.
    ln -s pig $out/bin/pi
  '';

  passthru = {
    inherit archiveSuffix;
  };

  meta = {
    description = "Pi rebuilt in Go as one native binary, running Pi's TypeScript extensions unchanged";
    homepage = "https://github.com/MichaelKinsy/PiG";
    changelog = "https://github.com/MichaelKinsy/PiG/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "pig";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}

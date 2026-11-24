{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  nodejs_22,
  # The version and source hash move together; `just bump agent-purge`
  # rewrites both literals before building.
  version ? "0.2.39",
  hash ? "sha256-YxLa0LzmLWO3UbQBf6Y+vl/S8J5yQwndADm5VVb4KLY=",
}:

stdenvNoCC.mkDerivation {
  pname = "agent-purge";
  inherit version;

  src = fetchFromGitHub {
    owner = "ZiChuanLan";
    repo = "agent-purge";
    tag = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [ makeWrapper ];

  # The npm package has zero production dependencies; its files field is the
  # runtime contract for the entry point and web console.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/agent-purge
    cp -r \
      backends \
      bin \
      lib \
      web \
      matrix.json \
      package.json \
      $out/libexec/agent-purge/
    install -Dm644 LICENSE $out/share/licenses/agent-purge/LICENSE

    makeWrapper ${lib.getExe nodejs_22} $out/bin/agent-purge \
      --add-flags "$out/libexec/agent-purge/bin/agent-purge.mjs"

    runHook postInstall
  '';

  # Upstream has no `--version`; this is the first command that follows the
  # entry point without depending on any coding agent being configured.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    $out/bin/agent-purge --help

    runHook postInstallCheck
  '';

  passthru.bump = [ "--build" ];

  meta = {
    description = "Local persona and prompt console for multiple coding agents";
    homepage = "https://github.com/ZiChuanLan/agent-purge";
    changelog = "https://github.com/ZiChuanLan/agent-purge/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "agent-purge";
    platforms = lib.platforms.unix;
  };
}

{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpmBuildHook,
  pnpm_12,
  nodejs_26,
  node-gyp,
  electron_44,
  copyDesktopItems,
  makeDesktopItem,
  makeBinaryWrapper,
  installShellFiles,
  jq,
  pkg-config,
  python3,
  cacert,
  libsecret,
  spdx-license-list-data,
  cloudflared,
  codex,
  gh,
  git,
  jujutsu,
  # The version, source hash, pnpm dependency hash and resource-monitor Cargo
  # hash all come from the same release tag; "just bump t3code" (nix-update)
  # moves them together via -s resourceMonitor.
  version ? "0.1.11",
  hash ? "sha256-oI8gyTWFgtTmVK+0cVQaEcfO8EzxUUOW5s8JFG/z/U8=",
  pnpmHash ? "sha256-s/vm8Ox4o/AYpNC/amYP1KFWwh7SY5bCmVBuIJn9f/c=",
  cargoHash ? "sha256-5cmG2daM1bVOA23gjjoalbx0fEL1hmqV6WZov0sUZp8=",
}:

let
  appName = "T3 Code (Beta)";
  electron = electron_44;
  nodejs = nodejs_26;
  pnpm = pnpm_12;
  desktopIcon = "assets/prod/black-universal-1024.png";

  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    tag = "v${version}";
    inherit hash;
  };

  resourceMonitor = rustPlatform.buildRustPackage {
    pname = "t3code-resource-monitor";
    inherit version src;

    sourceRoot = "${src.name}/native/resource-monitor";

    inherit cargoHash;

    meta = {
      description = "Native resource diagnostics sidecar for T3 Code";
      homepage = "https://t3.codes";
      changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      mainProgram = "t3-resource-monitor";
    };
  };

  runtimePackages = [
    codex
    gh
    git
    jujutsu
  ];

  wrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath runtimePackages)
    "--set-default"
    "T3CODE_CLOUDFLARED_PATH"
    (lib.getExe cloudflared)
    "--set-default"
    "T3CODE_RESOURCE_MONITOR_PATH"
    (lib.getExe resourceMonitor)
  ];
in
stdenv.mkDerivation {
  pname = "t3code";
  inherit version src;

  strictDeps = true;
  __structuredAttrs = true;

  postPatch = ''
    substituteInPlace apps/web/vite.config.ts \
      --replace-fail 'const host = explicitHost || "localhost";' \
                     'const host = explicitHost || "127.0.0.1";'

    mkdir -p .generated/third-party-licenses/spdx/v3.28.0
    cp ${spdx-license-list-data.json}/json/details/*.json \
      .generated/third-party-licenses/spdx/v3.28.0
  '';

  nativeBuildInputs = [
    cacert
    copyDesktopItems
    installShellFiles
    jq
    makeBinaryWrapper
    node-gyp
    nodejs
    pkg-config
    pnpm
    pnpmBuildHook
    pnpmConfigHook
    python3
  ];

  buildInputs = [ libsecret ];

  pnpmWorkspaces = [
    "@t3tools/monorepo"
    "t3..."
    "@t3tools/desktop..."
    "@t3tools/scripts..."
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit
      pnpm
      src
      version
      ;
    pname = "t3code";
    pnpmWorkspaces = [
      "@t3tools/monorepo"
      "t3..."
      "@t3tools/desktop..."
      "@t3tools/scripts..."
    ];
    fetcherVersion = 5;
    hash = pnpmHash;
  };

  preBuild = ''
    export pnpm_config_verify_deps_before_run=false

    node scripts/update-release-package-versions.ts ${version}

    export npm_config_nodedir=${nodejs}
    export ELECTRON_SKIP_BINARY_DOWNLOAD=1
    pnpm rebuild --pending "''${pnpmInstallFlags[@]}" --filter '!@t3tools/monorepo'
  '';

  pnpmBuildScript = "build:desktop";

  postBuild = ''
    pnpm vp cache clean
  '';

  dontPatchELF = true;
  noAuditTmpdir = true;

  installPhase = ''
    runHook preInstall

    mkdir --parents "$out"/libexec/t3code/apps/desktop "$out"/libexec/t3code/apps/server
    cp --recursive --no-preserve=mode node_modules "$out"/libexec/t3code
    cp --recursive --no-preserve=mode apps/server/{node_modules,dist} "$out"/libexec/t3code/apps/server
    cp --recursive --no-preserve=mode \
      apps/desktop/{node_modules,dist-electron} \
      "$out"/libexec/t3code/apps/desktop

    jq '.name = "t3code" | del(.productName)' apps/desktop/package.json \
      > "$out"/libexec/t3code/apps/desktop/package.json

    mkdir --parents "$out"/libexec/t3code/apps/desktop/prod-resources
    install --mode=444 ${desktopIcon} \
      "$out"/libexec/t3code/apps/desktop/prod-resources/icon.png
    install -Dm755 \
      native/browser-secret/build/${stdenv.hostPlatform.node.arch}/t3-browser-secret \
      "$out"/libexec/t3code/apps/desktop/prod-resources/browser-secret/t3-browser-secret

    find "$out"/libexec/t3code -xtype l -delete

    makeWrapper ${lib.getExe nodejs} "$out"/bin/t3 \
      --add-flags "$out"/libexec/t3code/apps/server/dist/bin.mjs \
      ${lib.escapeShellArgs wrapperArgs}

    makeWrapper ${lib.getExe electron} "$out"/bin/t3code-desktop \
      --add-flags "$out"/libexec/t3code/apps/desktop \
      --inherit-argv0 \
      ${lib.escapeShellArgs wrapperArgs}

    mkdir --parents \
      "$out"/share/icons/hicolor/{1024x1024,scalable}/apps
    install --mode=444 ${desktopIcon} \
      "$out"/share/icons/hicolor/1024x1024/apps/t3code.png
    install --mode=444 assets/prod/logo.svg \
      "$out"/share/icons/hicolor/scalable/apps/t3code.svg

    runHook postInstall
  '';

  postInstall = ''
    for shell in bash fish zsh; do
      installShellCompletion --cmd t3 --"$shell" <("$out/bin/t3" --completions "$shell")
    done
  '';

  postFixup = ''
    for module in "$out"/libexec/t3code/node_modules/.pnpm/node-pty@*/node_modules/node-pty/prebuilds/linux-${stdenv.hostPlatform.node.arch}/pty.node; do
      patchelf --add-rpath ${lib.makeLibraryPath [ stdenv.cc.cc.lib ]} "$module"
    done
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "t3code";
      desktopName = appName;
      comment = "Minimal web GUI for coding agents";
      exec = "t3code-desktop %U";
      terminal = false;
      icon = "t3code";
      startupWMClass = "t3code";
      categories = [ "Development" ];
    })
  ];

  passthru = {
    inherit resourceMonitor;
    bump = [
      "--use-github-releases"
      "-s"
      "resourceMonitor"
    ];
  };

  meta = {
    description = "Minimal web GUI for coding agents";
    homepage = "https://t3.codes";
    downloadPage = "https://t3.codes/download";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "t3code-desktop";
    platforms = [ "x86_64-linux" ];
  };
}

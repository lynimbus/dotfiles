{
  lib,
  buildNpmPackage,
  fetchurl,
  fd,
  makeBinaryWrapper,
  ripgrep,
  src,
  writableTmpDirAsHomeHook,
  versionCheckHook,
}:
let
  version = (lib.importJSON "${src}/packages/coding-agent/package.json").version;
in
buildNpmPackage (finalAttrs: {
  pname = "pi-coding-agent";
  inherit version src;

  npmWorkspace = "packages/coding-agent";
  npmDepsHash = "sha256-eKghIpCAKawZm0Uf2iG6y1fz21Z5jNnMiAFJ5Quj3GI=";
  npmFlags = [ "--legacy-peer-deps" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  makeCacheWritable = true;

  modelData = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha256-Cz34eRtIghbzCdkIeJKUp0S7Ybuq0SPZQJjlbflTjSU=";
  };

  preConfigure = ''
    mkdir -p packages/ai/src/providers/data
    tar --extract --gzip --file=${finalAttrs.modelData} \
      --directory=packages/ai/src/providers/data \
      --strip-components=4 \
      package/dist/providers/data
  '';

  buildPhase = ''
    runHook preBuild
    npm run build:offline
    runHook postBuild
  '';

  dontNpmPrune = true;

  preInstall = ''
    npm prune --omit=dev --no-save
  '';

  nativeBuildInputs = [ makeBinaryWrapper ];

  postInstall = ''
    workspaceRoot="$out/lib/node_modules/pi-monorepo"
    mkdir -p "$workspaceRoot/packages"
    # node_modules/@earendil-works/* are symlinks into ../../packages/*, so all
    # workspace packages have to be copied next to node_modules. Copy whatever
    # `packages/*` currently holds instead of a hardcoded list (upstream adds and
    # removes packages between versions, e.g. session-backends -> evals in 1.0.0).
    cp -r packages/* "$workspaceRoot/packages/"
    find "$workspaceRoot/node_modules" -xtype l -delete
  '';

  postFixup = ''
    wrapProgram $out/bin/pi --prefix PATH : ${
      lib.makeBinPath [
        fd
        ripgrep
      ]
    } \
      --set-default PI_SKIP_VERSION_CHECK 1 \
      --set-default PI_TELEMETRY 0
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgram = "${placeholder "out"}/bin/pi";
  versionCheckProgramArg = "--version";

  meta = {
    description = "Coding agent CLI built from the Pi main branch";
    homepage = "https://github.com/earendil-works/pi";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
})

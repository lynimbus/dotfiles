{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  nodejs_22,
  # The published npm tarball is the only source: it already carries the built
  # dist/, so nothing is compiled here, and \`just bump obelisk\` moves the
  # version and its hash to the latest release together. The package declares no
  # runtime dependencies at all, which is why this is a plain fetchurl instead of
  # a node_modules build, and why the tarball is small enough to be the source of
  # record.
  version ? "0.3.2",
  hash ? "sha256-W0xh6gjCFIJ6hwGTP4MeP+VRgwNi6NbJZ9HcXUFg0qk=",
}:

stdenv.mkDerivation {
  pname = "obelisk-cli";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@obelisk-apps/cli/-/cli-${version}.tgz";
    inherit hash;
  };

  # npm's package/ layout, kept as it is: the CLI resolves dist/ relative to its
  # own file, so flattening the tree would break the provider registry.
  sourceRoot = "package";

  dontBuild = true;
  dontConfigure = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    packageRoot=$out/lib/node_modules/@obelisk-apps/cli
    mkdir -p "$packageRoot"
    cp -r dist package.json README.md "$packageRoot"/

    # node:sqlite still prints an ExperimentalWarning on every run, on stderr
    # where the agent reads the query result. The flag is scoped to this wrapper
    # rather than NODE_OPTIONS so it cannot reach the agent's own node processes.
    makeWrapper ${nodejs_22}/bin/node $out/bin/obelisk \
      --add-flags "--disable-warning=ExperimentalWarning" \
      --add-flags "$packageRoot/dist/cli/src/obelisk.js"

    runHook postInstall
  '';

  passthru.bump = [ ];

  meta = {
    description = "Index past coding-agent sessions into one local SQLite database, queryable by agents";
    homepage = "https://github.com/tommy0103/obelisk";
    changelog = "https://github.com/tommy0103/obelisk/releases";
    license = lib.licenses.agpl3Only;
    mainProgram = "obelisk";
    platforms = [ "x86_64-linux" ];
  };
}

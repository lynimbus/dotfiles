{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go_1_27,
  makeWrapper,
  versionCheckHook,
  bun,
  releaseLib,
  releaseManifest,
}:

let
  release = releaseLib.githubRelease {
    pname = "mygo";
    manifest = releaseManifest;
  };

  # The CLI's version is a const of the tagged source itself, which the npm
  # manifests hold to the same value (scripts/version.ts), so the tag the
  # manifest names is the only version there is to track. This hash and
  # vendorHash below change with it, and the build names the new ones in its
  # error.
  src = fetchFromGitHub {
    owner = "egoist";
    repo = "mygo";
    tag = "v${release.version}";
    hash = "sha256-l4hjFUQMSSM9sNEzWikrn6eqJ3bO3FpBT5TaYGSKbiA=";
  };
in
(buildGoModule.override { go = go_1_27; }) {
  pname = "mygo";
  inherit (release) version;

  inherit src;

  subPackages = [ "cmd/mygo" ];

  # The version is compiled in as a const; there is nothing to inject.
  ldflags = [
    "-s"
    "-w"
  ];

  vendorHash = "sha256-XM/Wi62946L/p6tNAWza1sZPx+2NKAI5bM3+2t580t0=";

  # The tests drive the go tool and bun as subprocesses (dev, build, doctor),
  # which the build sandbox has neither complete nor networked; the version
  # smoke below covers the CLI running at all.
  doCheck = false;

  # mygo dev and mygo build run `go` and `bun` as subprocesses. The go on
  # PATH is a minor behind what mygo and the apps it scaffolds ask for, and
  # the build's GOTOOLCHAIN=local means the toolchain on PATH is the only one
  # they get, so the wrapper puts the go the module names there itself, and
  # bun with it, which the web template's `bun install` and `bun run` need.
  # go is a forbidden reference in a go build by default, allowed here because
  # the tool exists to run it.
  allowGoReference = true;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/mygo --prefix PATH : ${
      lib.makeBinPath [
        go_1_27
        bun
      ]
    }
    install -Dm644 ${src}/LICENSE $out/share/licenses/mygo/LICENSE
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "CLI that scaffolds, develops and packages MyGo desktop apps";
    homepage = "https://github.com/egoist/mygo";
    changelog = "https://github.com/egoist/mygo/releases/tag/v${release.version}";
    license = lib.licenses.mit;
    mainProgram = "mygo";
    platforms = [ "x86_64-linux" ];
  };
}

{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go_1_27,
  makeWrapper,
  versionCheckHook,
  bun,
  # The CLI's version is a const of the tagged source itself, which the npm
  # manifests hold to the same value (scripts/version.ts), so the release
  # tag is the only version there is to track. `just bump mygo`
  # (nix-update) moves the version, the source hash and vendorHash in
  # lockstep.
  version ? "0.8.3",
  hash ? "sha256-QWF13vtxEPlVqruaqPikSBDqs0bd1kw74wYfHWM7uwE=",
  vendorHash ? "sha256-bwaBfuv6E6HGgnQkyyFhLkYk0Q4X4sEspQjAB5dED5U=",
}:

let
  src = fetchFromGitHub {
    owner = "egoist";
    repo = "mygo";
    tag = "v${version}";
    inherit hash;
  };
in
(buildGoModule.override { go = go_1_27; }) {
  pname = "mygo";
  inherit version;

  inherit src;

  subPackages = [ "cmd/mygo" ];

  # The version is compiled in as a const; there is nothing to inject.
  ldflags = [
    "-s"
    "-w"
  ];

  inherit vendorHash;

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

  passthru.bump = [ ];

  meta = {
    description = "CLI that scaffolds, develops and packages MyGo desktop apps";
    homepage = "https://github.com/egoist/mygo";
    changelog = "https://github.com/egoist/mygo/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "mygo";
    platforms = [ "x86_64-linux" ];
  };
}

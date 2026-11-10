{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  openjdk17,
  versionCheckHook,
  # d8 and r8 exist only as the r8.jar artifact on Google Maven: there is no
  # GitHub release and no JSON manifest to pin them from — the version index
  # is maven-metadata.xml, which passthru.bump reads — so the version and its
  # hash live here and are bumped together. The jar runs on JDK 17, the JDK
  # this environment pins.
  version ? "9.5.29",
  hash ? "sha256-+Mdi/4RkCxAIO5NKRyeHWKdmWXfmGPqwySf/8AUh3qM=",
}:

stdenv.mkDerivation {
  pname = "r8";
  inherit version;

  src = fetchurl {
    url = "https://dl.google.com/android/maven2/com/android/tools/r8/${version}/r8-${version}.jar";
    inherit hash;
  };

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm644 "$src" "$out/share/java/r8.jar"

    # One jar, two entry classes: d8 compiles java bytecode to dex, r8
    # shrinks and dexes it, so each command wraps the same jar with its own
    # main class.
    makeWrapper "${openjdk17}/bin/java" "$out/bin/r8" \
      --add-flags "-cp $out/share/java/r8.jar com.android.tools.r8.R8"
    makeWrapper "${openjdk17}/bin/java" "$out/bin/d8" \
      --add-flags "-cp $out/share/java/r8.jar com.android.tools.r8.D8"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  # nix-update cannot enumerate a Maven repository, so the bump hands it the
  # version instead: docs/bump-packages.sh reads this index and passes the
  # newest stable version as a fixed --version. --build reruns
  # versionCheckHook, so a bump that lands on a jar whose r8 --version does
  # not match fails here rather than at switch time.
  passthru.bump = [
    "--bump-maven=https://dl.google.com/android/maven2/com/android/tools/r8/maven-metadata.xml"
    "--build"
  ];

  meta = {
    description = "Android dexer (d8) and shrinker/optimizer (r8) from Google Maven";
    homepage = "https://r8.googlesource.com/r8";
    changelog = "https://r8.googlesource.com/r8/+/refs/heads/main/CHANGELOG.md";
    license = lib.licenses.bsd3;
    mainProgram = "r8";
    platforms = lib.platforms.unix;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
}

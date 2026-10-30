{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  openjdk17,
  versionCheckHook,
  # d8 and r8 exist only as the r8.jar artifact on Google Maven: there is no
  # GitHub release and no JSON manifest to pin them from — the version index
  # is maven-metadata.xml — so the version and its hash live here and are
  # bumped together. The jar runs on JDK 17, the JDK this environment pins.
  version ? "9.5.28",
  hash ? "sha256-OKn/quu9F9FRTj7L/1qFuYm7E8VRueIkx0CVFO6oT/U=",
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

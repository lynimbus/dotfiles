{ pkgs, ... }:

{
  # `nsh` discovers the Android SDK through ANDROID_HOME and expects the
  # composed layout pkgs/nsh-android-sdk builds: build-tools, platforms,
  # platform-tools and the NDK, all symlinked in one store path (the
  # composition's root is its libexec/android-sdk). Exporting it globally
  # (instead of a dev shell) is what makes `nsh package --target android` work
  # from any directory without entering anything.
  home.sessionVariables = {
    ANDROID_HOME = "${pkgs.nsh-android-sdk.androidsdk}/libexec/android-sdk";
  };
}

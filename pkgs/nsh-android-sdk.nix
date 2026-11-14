{
  androidenv,
  # `nsh` builds an Android app with the SDK's build tools (aapt2, zipalign,
  # apksigner) against `platforms/android-<level>/android.jar` (its default
  # target level is 35) and cross-compiles Rust code with the NDK's clang (its
  # minimum API level is 26). The composed SDK has exactly the layout the CLI
  # discovers through ANDROID_HOME: build-tools/<newest>, platforms/,
  # platform-tools/ and ndk/<version>.
  version ? "35",
  buildToolsVersion ? "35.0.1",
}:

androidenv.composeAndroidPackages {
  platformVersions = [ version ];
  buildToolsVersions = [ buildToolsVersion ];
  includeNDK = true;
  # The emulator is not part of this: `nsh run --target android` installs on
  # a device over adb (pkgs.android-tools is on PATH already). Add
  # includeEmulator here if one is ever wanted.
}

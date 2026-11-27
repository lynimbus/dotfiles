{
  lib,
  mkProtonBinDerivation,
  fetchzip,
  version ? "11.0-20261127",
  hash ? "sha256-JWeYFM/r60Y2HRAhdPrcp8mo0F6+TiFF6R/Z45GP/SQ=",
}:

let
  src = fetchzip {
    url = "https://github.com/nanomatters/proton-salkim/releases/download/wineland-${version}/proton-wineland-${version}-x86_64_v3.tar.xz";
    inherit hash;
  };
in
(mkProtonBinDerivation (finalAttrs: {
  steamDisplayName = "Proton-Wineland";

  pname = "proton-wineland-bin";
  inherit version;

  variants = {
    "x86_64-linux" = {
      toolName = "proton-wineland-${finalAttrs.version}-x86_64_v3";
      inherit src;
    };
  };

  passthru.bump = [
    "--version-regex=^wineland-(.*)$"
    "--build"
  ];

  meta = {
    description = ''
      Compatibility tool for Steam Play based on Proton-CachyOS with Wayland-first defaults.

      (Intended for use in `programs.steam.extraCompatPackages` and Lutris.)
    '';
    homepage = "https://github.com/nanomatters/proton-salkim";
    changelog = "https://github.com/nanomatters/proton-salkim/releases/tag/wineland-${finalAttrs.version}";
    license = lib.licenses.bsd3;
  };
})).overrideAttrs
  {
    # mkProtonBinDerivation sets `src` via `inherit (variants.${system}) src`,
    # which puts `unsafeGetAttrPos "src"` inside nixpkgs instead of this file
    # and breaks nix-update. Re-declaring `src` here restores its position.
    inherit src;
  }

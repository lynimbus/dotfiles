{ lib }:
let
  sri =
    digest:
    builtins.convertHash {
      hash = lib.removePrefix "sha256:" digest;
      hashAlgo = "sha256";
      toHashFormat = "sri";
    };

  readManifest = path: builtins.fromJSON (builtins.readFile path);

  # A repository can publish several release series under one tag namespace
  # (lorca tags the app desktop-v* and its CLI v*), so the manifest may be the
  # list endpoint rather than one release. That list is ordered by publication
  # time, which is not version order, and its first entry is not necessarily the
  # wanted series.
  select =
    {
      pname,
      document,
      tagPrefix,
    }:
    let
      version = release: lib.removePrefix tagPrefix release.tag_name;
      candidates = builtins.filter (
        release: !release.draft && !release.prerelease && lib.hasPrefix tagPrefix release.tag_name
      ) document;
    in
    if candidates == [ ] then
      throw "${pname}: the release list has no ${tagPrefix} release"
    else
      lib.foldl' (
        best: release: if lib.versionOlder (version best) (version release) then release else best
      ) (builtins.head candidates) candidates;
in
{
  inherit sri readManifest;

  githubRelease =
    {
      pname,
      manifest,
      tagPrefix ? "v",
    }:
    let
      document = readManifest manifest;
      release =
        if builtins.isList document then
          select {
            inherit pname tagPrefix;
            inherit document;
          }
        else
          document;
      version = lib.removePrefix tagPrefix release.tag_name;
    in
    {
      inherit version;
      asset =
        name:
        let
          found = lib.findFirst (asset: asset.name == name) null release.assets;
        in
        if found == null then
          throw "${pname}: release ${version} has no ${name} asset"
        else
          {
            url = found.browser_download_url;
            hash = sri found.digest;
          };
    };
}

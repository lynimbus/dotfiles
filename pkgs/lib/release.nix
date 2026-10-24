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
in
{
  inherit sri readManifest;

  githubRelease =
    { pname, manifest }:
    let
      release = readManifest manifest;
      version = lib.removePrefix "v" release.tag_name;
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

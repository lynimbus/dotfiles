# Links from this repo into the home directory, kept out of the store so a
# config file stays editable without a rebuild. Every module that ships files
# from home/ links them through here.
{
  config,
  repoRoot,
}:

let
  livePath = path: config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/${path}";
in
{
  liveFile = path: {
    source = livePath path;
  };

  liveFiles =
    {
      from,
      into,
      files,
    }:
    builtins.listToAttrs (
      map (file: {
        name = "${into}/${file}";
        value.source = livePath "${from}/${file}";
      }) files
    );
}

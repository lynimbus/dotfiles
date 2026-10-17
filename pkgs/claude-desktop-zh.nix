{
  lib,
  buildFHSEnv,
  runCommandLocal,
  fetchFromGitHub,
  jq,
  perl,
  claude-desktop,
}:

let
  translations = fetchFromGitHub {
    owner = "javaht";
    repo = "claude-desktop-zh-cn";
    rev = "b1330b9aaf2f85e6e4ba05606e70d785686cd588";
    hash = "sha256-tj6OXnhXbHTo17BkaMycK4DH8rH5ckT8SLHY4OS/+ng=";
  };

  locales = [
    "zh-CN"
    "zh-TW"
  ];

  scripts = ./claude-desktop-zh;

  # The app tree the FHS rootfs links to, patched in place.
  patched = runCommandLocal "claude-desktop-zh-${claude-desktop.version}"
    {
      nativeBuildInputs = [
        jq
        perl
      ];
      meta = claude-desktop.meta // {
        description = "${claude-desktop.meta.description} (简体中文)";
      };
    }
    ''
      cp -a ${claude-desktop.unwrapped}/. "$out"
      chmod -R u+w "$out"

      app="$out/lib/claude-desktop/resources"
      i18n="$app/ion-dist/i18n"
      resources=${translations}/resources

      perl ${scripts}/retarget.pl "$out" ${claude-desktop.unwrapped}

      ${lib.concatMapStringsSep "\n" (locale: ''
        # Merge the shipped English catalog with the translation, falling back
        # to English for keys the translation does not cover yet.
        jq -c -s '.[0] as $en | .[1] as $zh | reduce ($en | keys_unsorted[]) as $k ({}; .[$k] = (if $zh | has($k) then $zh[$k] else $en[$k] end))' \
          "$i18n/en-US.json" "$resources/frontend-${locale}.json" > "$i18n/${locale}.json"
        jq -c -s '.[0] as $en | .[1] as $zh | reduce ($en | keys_unsorted[]) as $k ({}; .[$k] = (if $zh | has($k) then $zh[$k] else $en[$k] end))' \
          "$app/en-US.json" "$resources/desktop-${locale}.json" > "$app/${locale}.json"
        cp "$i18n/dynamic/en-US.json" "$i18n/dynamic/${locale}.json"
        echo "catalogs: ${locale}"
      '') locales}

      perl ${scripts}/patch-whitelist.pl "$app/ion-dist/assets/v1" ${lib.concatStringsSep " " locales}

      # The online view translates by matching visible English text. Restrict
      # the table to plain strings and skip structural JS identifiers.
      jq -c -s '.[0] as $en | .[1] as $zh | reduce ($en | keys_unsorted[]) as $k ({}; .[$k] = (if $zh | has($k) then $zh[$k] else $en[$k] end))' \
        "$i18n/en-US.json" "$resources/frontend-zh-CN.json" \
        | jq -c 'with_entries(select((.value | type) == "string")
                  | select(.key | length <= 1000)
                  | select(.key != .value)
                  | select(.key | test("\\n") | not)
                  | select(.key | test("\\{") | not))' > "$TMPDIR/dom.json"
      perl ${scripts}/patch-asar.pl "$app/app.asar" "$TMPDIR/dom.json" ${scripts}/inject.js.tpl zh-CN
      perl ${scripts}/patch-locale.pl "$app/app.asar" zh-CN
    '';

  # Rebuild the shell from the upstream arguments, swapping only the app tree.
  # The original shell keeps the unwrapped package in its target list, and its
  # rootfs is a fixed set of symlinks into that store path.
  upstreamArgs = claude-desktop.args or (throw "claude-desktop does not expose buildFHSEnv arguments");

  shell = buildFHSEnv (
    upstreamArgs // {
      inherit (claude-desktop) pname version meta;
      targetPkgs = pkgs: map (pkg: if pkg == claude-desktop.unwrapped then patched else pkg) (upstreamArgs.targetPkgs pkgs);
      extraInstallCommands = lib.replaceStrings [ "${claude-desktop.unwrapped}" ] [ "${patched}" ] (
        upstreamArgs.extraInstallCommands or ""
      );
      passthru = (claude-desktop.passthru or { }) // {
        inherit patched;
        unwrapped = patched;
      };
    }
  );
in
shell

{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
  cmake,
  pkg-config,
  fcitx5,
  nlohmann_json,
  openssl,
}:

let
  rev = "c08ae57cb88b6a4a46f4a5e9c1d6d11c5e69222e";
  srcHash = "sha256-OulZ8oizG1XzDGX4FCZxlS5Qe3ss73isoyXPgGQIeKY=";
  cargoHash = "sha256-sLU+ReJ/gbekiW+fa8ilQbVZ17KMyla5sc1EKy7OuaA=";
  dataTag = "data-v3";
  dataHash = "sha256-Qq0I+y/p9JfAqxkcEg8FOG9q3MnXE8MoMgCq7WkOYvM=";

  src = fetchFromGitHub {
    owner = "qingjian-team";
    repo = "qingjian";
    inherit rev;
    hash = srcHash;
  };

  data = fetchurl {
    url = "https://github.com/qingjian-team/qingjian/releases/download/${dataTag}/qingjian-data.tar.gz";
    hash = dataHash;
  };
in
rustPlatform.buildRustPackage {
  pname = "qingjian";
  version = "0.1.3-unstable-${lib.substring 0 8 rev}";

  inherit
    src
    cargoHash
    data
    ;

  cargoBuildFlags = [
    "-p"
    "qingjian-linux-server"
  ];
  doCheck = false;

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    fcitx5
    nlohmann_json
    openssl
  ];

  postBuild = ''
    cmake -S apps/linux/fcitx5 -B fcitx5-build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
    cmake --build fcitx5-build --parallel $NIX_BUILD_CORES
  '';

  installPhase = ''
    runHook preInstall

    server=$(find target -name qingjian-linux-server -type f -executable | head -n 1)
    install -Dm755 "$server" $out/bin/qingjian-linux-server

    install -Dm755 fcitx5-build/qingjian.so $out/lib/fcitx5/qingjian.so
    install -Dm644 apps/linux/fcitx5/data/addon/qingjian.conf $out/share/fcitx5/addon/qingjian.conf
    install -Dm644 apps/linux/fcitx5/data/inputmethod/qingjian.conf $out/share/fcitx5/inputmethod/qingjian.conf
    install -Dm644 assets/icon/logo.png $out/share/icons/hicolor/128x128/apps/qingjian.png

    res=$out/share/qingjian/resources
    mkdir -p $res $res/assets
    tar -xzf ${data} -C $res --exclude='._*'
    cp -r assets/emoji assets/levels assets/glossary assets/sample $res/assets/

    runHook postInstall
  '';

  meta = {
    description = "青简 Qingjian：候选词旁附所学语言译词的拼音输入法（fcitx5 插件 + 本地 server）";
    homepage = "https://github.com/qingjian-team/qingjian";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "qingjian-linux-server";
  };
}

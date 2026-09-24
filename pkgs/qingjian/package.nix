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
  rev = "40e3e550425466e6ba9c0a14de3a77ed04862799";
  srcHash = "sha256-Qd4udxAyhAvejjjV/8o73ITgauh/31wyfuzDnmsLcWY=";
  cargoHash = "sha256-sLU+ReJ/gbekiW+fa8ilQbVZ17KMyla5sc1EKy7OuaA=";
  dataTag = "data-v2";
  dataHash = "sha256-TVn9s/goCXNr7r4jtCzsKD/9h/ao8CQ7lSkcRg8fDKo=";
  modelHash = "sha256-7tW9C9oMe9i0PRrLLcRnjUu+KVvUeysNTurOCvna/00=";

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

  model = fetchurl {
    url = "https://github.com/qingjian-team/qingjian/releases/download/${dataTag}/model.qjm";
    hash = modelHash;
  };
in
rustPlatform.buildRustPackage {
  pname = "qingjian";
  version = "0.1.3-unstable-${lib.substring 0 8 rev}";

  inherit src cargoHash;

  cargoBuildFlags = [ "-p" "qingjian-linux-server" ];
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
    mkdir -p $res/data/generated $res/data/model $res/assets
    tar -xzf ${data} -C $res/data/generated --exclude='._*'
    install -Dm644 ${model} $res/data/model/model.qjm
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

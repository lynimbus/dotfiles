{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  glibc,
  libgcc,
  versionCheckHook,
  # sing-box 的 unstable 渠道就是 GitHub prerelease（alpha/beta/rc tag），官方
  # 给每个 tag 挂好各平台的预编译 tarball，这里只取 linux-amd64 那个。版本
  # 和 hash 都是本文件里的字面量，`just bump sing-box`（nix-update）按
  # legacyPackages 属性路径找到后整体改写。渠道钉在 unstable 上靠的是
  # docs/bump-packages.sh 里 sing-box 的 --version=unstable 和
  # --version-regex：前者放行 prerelease（默认的 stable 偏好会把它们全部
  # 跳过），后者的捕获组只认 alpha/beta/rc tag 并顺带剥掉 v 前缀，稳定版
  # 一律筛掉，所以 bump 不会串到 stable 渠道。tag 集覆盖
  # quic/dhcp/wireguard/clash_api/tailscale/naive 等，比 nixpkgs 或源码
  # flake 自己编出来的全。注意官方的 plain linux-amd64 构建虽是 CGO 关闭，
  # 却是 PIE 动态链接（interpreter 指向 /lib64/ld-linux），沙箱里跑不了，
  # 所以要 autoPatchelf 换 interpreter；naive 出站在运行时按找到的绝对路径
  # dlopen 随包的 libcronet.so（NEEDED 里还有 libm 等 glibc 组件），
  # appendRunpaths 给所有 ELF 都补上 glibc 的 rpath。musl 变体是全静态
  # 但不含 libcronet.so，会砍掉 naive 出站，故不取它。
  version ? "1.15.0-alpha.13",
  hash ? "sha256-v8OfZDpezBtwLFcj/2YuYd3oE/ErOvDQz85PYp/3QEc=",
}:

stdenv.mkDerivation {
  pname = "sing-box";
  inherit version;

  src = fetchurl {
    url = "https://github.com/SagerNet/sing-box/releases/download/v${version}/sing-box-${version}-linux-amd64.tar.gz";
    inherit hash;
  };

  sourceRoot = "sing-box-${version}-linux-amd64";

  nativeBuildInputs = [ autoPatchelfHook ];
  # libcronet.so 除了 glibc 还要 libgcc_s；appendRunpaths 是
  # autoPatchelfHook 的官方扩展点，patchelf 的 rpath 会被它整体改写，
  # 手动 --add-rpath 是不行的（postFixup 字符串先于 autoPatchelf 跑）。
  buildInputs = [
    glibc
    libgcc
  ];
  appendRunpaths = [ "${glibc}/lib" ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # tarball 里就三样东西：主二进制、LICENSE、libcronet.so，后两者同目录。
    # libcronet.so 必须跟着装进 bin：cronet-go 的 loader_unix.go 在 Go 层
    # 自己找库（os.Executable() 所在目录、LD_LIBRARY_PATH 各段、
    # /usr/local/lib、/usr/lib），对找到的文件按绝对路径 purego dlopen，
    # 全程不查 ELF 的 RUNPATH，也没有专用的路径环境变量。可执行文件
    # 所在目录是无条件搜索的第一顺位，也就是上游 tarball 自带的布局；
    # 不用 naive 的配置不会碰这个文件。此前 $out/lib + wrapper 挂
    # LD_LIBRARY_PATH 的做法在本机是坏的：makeWrapper 的 --set-default
    # 只在变量未设置时才注入，而登录会话实测已被 pipewire-jack 全局
    # export 了 LD_LIBRARY_PATH，wrapper 静默失效，naive 一律
    # cronet: library not found。
    install -Dm755 sing-box $out/bin/sing-box
    install -Dm644 libcronet.so $out/bin/libcronet.so
    install -Dm644 LICENSE $out/share/licenses/sing-box/LICENSE

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  # sing-box 没有全局 --version 标志，版本走 `sing-box version` 子命令。
  versionCheckProgramArg = "version";
  # naive 出站在初始化时才加载 cronet 引擎，`check` 子命令同样会走到，
  # 于是用一条最小 naive 配置把 dlopen 路径整个跑一遍：versionCheck 只
  # 比对版本号，上游改库文件名或搜索策略时它发现不了。构建沙箱里没有
  # 环境变量污染，所以故意预置一个无关的 LD_LIBRARY_PATH 复现被污染的
  # 真实会话，exe-dir 搜索必须不吃这套才应该过。
  postInstallCheck = ''
    printf '%s\n' '{"outbounds":[{"type":"naive","tag":"check","server":"127.0.0.1","server_port":443,"username":"u","password":"p","tls":{"enabled":true,"server_name":"example.com"}}]}' > naive-check.json
    LD_LIBRARY_PATH=/definitely/not/here $out/bin/sing-box check -c naive-check.json
  '';

  meta = {
    description = "Universal proxy platform (upstream unstable prerelease binaries)";
    homepage = "https://sing-box.sagernet.org";
    changelog = "https://github.com/SagerNet/sing-box/releases";
    license = lib.licenses.gpl3Only;
    mainProgram = "sing-box";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}

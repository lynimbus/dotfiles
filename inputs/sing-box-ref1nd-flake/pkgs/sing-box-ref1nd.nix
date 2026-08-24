{
  lib,
  buildGoModule,
  coreutils,
  installShellFiles,
  # ── 由 flake 传入 ──
  src, # reF1nd/sing-box reF1nd-testing 分支源码（flake input，跟随分支最新提交）
  srcRev ? src.rev or "unknown", # 当前锁定的提交 hash
  withEBPF ? true, # 是否启用 eBPF（fork 把 BPF 字节码预生成并提交，纯 Go 构建即可）
}:
# 在 nixpkgs 上游 sing-box 包基础上，替换 src/version/tags/ldflags 而来
buildGoModule (finalAttrs: {
  pname = "sing-box-ref1nd";
  # 版本号跟随分支提交（短 hash）；nix flake update sing-box-src 后自动变化
  version = "unstable-${lib.substring 0 8 srcRev}";

  __structuredAttrs = true;

  inherit src;

  # TODO: 占位 hash。首次 nix build 会报 hash mismatch，
  # 报错里的 `got: sha256-...` 即为真实 vendorHash，替换到这里即可。
  # 若更新分支后构建报 hash mismatch，同样取 `got:` 值替换。
  vendorHash = "sha256-/kMsTMPlxxc/oAF0+q6d9W8K7hToMwzsQp2DzziZQMQ=";

  # 与 fork 自带 release/DEFAULT_BUILD_TAGS_OTHERS 保持一致，
  # 比上游多出 with_connection_history / with_cloudflared / with_naive_outbound /
  # with_usbip / with_openvpn / with_openconnect 等特性。
  # withEBPF = true 时追加 with_ebpf：使用仓库内 common/ebpf/internal/bpfgen/
  # 预生成的 BPF 字节码与绑定，不需要 clang / 内核头文件。
  tags = [
    "with_gvisor"
    "with_quic"
    "with_dhcp"
    "with_wireguard"
    "with_utls"
    "with_acme"
    "with_clash_api"
    "with_connection_history"
    "with_tailscale"
    "with_ccm"
    "with_ocm"
    "with_cloudflared"
    "with_naive_outbound"
    "with_usbip"
    "with_openvpn"
    "with_openconnect"
    "badlinkname"
    "tfogo_checklinkname0"
  ]
  ++ lib.optional withEBPF "with_ebpf";

  subPackages = [
    "cmd/sing-box"
  ];

  env = {
    CGO_ENABLED = 0;
  };

  nativeBuildInputs = [
    installShellFiles
  ];

  # fork release/LDFLAGS：multipathtcp 关闭、兼容 tlssha1/tlsunsafeekm、跳过 linkname 检查
  ldflags = [
    "-X=github.com/sagernet/sing-box/constant.Version=${finalAttrs.version}"
    "-X=runtime.godebugDefault=multipathtcp=0,tlssha1=1,tlsunsafeekm=1"
    "-checklinkname=0"
  ];

  # 上游同样跳过测试（大量测试依赖网络环境）
  doCheck = false;

  postInstall = ''
    installShellCompletion release/completions/sing-box.{bash,fish,zsh}

    substituteInPlace release/config/sing-box{,@}.service \
      --replace-fail "/usr/bin/sing-box" "$out/bin/sing-box" \
      --replace-fail "/bin/kill" "${coreutils}/bin/kill"
    install -Dm444 -t "$out/lib/systemd/system/" release/config/sing-box{,@}.service

    install -Dm444 release/config/sing-box.rules $out/share/polkit-1/rules.d/sing-box.rules
    install -Dm444 release/config/sing-box-split-dns.xml $out/share/dbus-1/system.d/sing-box-split-dns.conf
  '';

  meta = {
    homepage = "https://github.com/reF1nd/sing-box";
    description = "Universal proxy platform（reF1nd fork，reF1nd-testing 分支，带 eBPF：URLTest fallback、TCP keep-alive 可调、connection history 等）";
    license = lib.licenses.gpl3Plus;
    mainProgram = "sing-box";
  };
})

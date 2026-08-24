# sing-box-ref1nd flake

[reF1nd/sing-box](https://github.com/reF1nd/sing-box) **reF1nd-testing** 分支的 Nix 打包，
**默认启用 eBPF**，并**自动跟踪分支最新提交**（不锁定死版本）。

nixpkgs 里只有上游 SagerNet 的 sing-box，本 flake 打包了 reF1nd fork，包含其特有功能：

- **eBPF inbound**（`with_ebpf`，仓库内预生成 BPF 字节码，纯 Go 构建）
- URLTest 出站 `fallback`（按可用性 + 顺序选择，支持 `max_delay` 淘汰）
- TCP keep-alive 可调选项（`tcp_keep_alive` / `tcp_keep_alive_interval` / `tcp_keep_alive_count`）
- Inbound 拒绝未知 SNI（`reject_unknown_sni`）
- 连接历史、cloudflared / naive / usbip / openvpn / openconnect 出站等

## 跟踪最新版本

源码通过 flake input 跟踪 `reF1nd-testing` 分支，当前锁定在
`reF1nd-testing` 最新提交（短 hash 见 `pkgs/sing-box-ref1nd.nix` 的 version，或 `sing-box version` 输出）。

```bash
# 更新到分支最新提交（改 flake.lock，然后重新构建）
nix flake update sing-box-src

# 只查看最新提交
git ls-remote https://github.com/reF1nd/sing-box.git refs/heads/reF1nd-testing
```

## 快速使用

```bash
# 构建（首次会提示替换 vendorHash，见下）
nix build .#sing-box-ref1nd

# 构建并查看版本
nix build .#sing-box-ref1nd --print-build-logs
./result/bin/sing-box version        # Tags 里应包含 with_ebpf

# 临时进入 shell 使用
nix shell .#sing-box-ref1nd

# 冒烟求值检查（不构建）
nix flake check --no-build
```

### 首次构建：替换 vendorHash

依赖 vendor 目录的 hash 只能在真实 nix 环境算出，故用占位符（`lib.fakeHash`）。
首次构建会报错：

```
error: hash mismatch in fixed-output derivation '/nix/store/...-go-modules.drv':
  specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
     got:    sha256-<真实值>
```

把 `pkgs/sing-box-ref1nd.nix` 里的 `vendorHash = lib.fakeHash;` 换成 `got:` 后面的值。
**以后每次 `nix flake update sing-box-src` 更新分支后，如果依赖有变，也需要照此重填。**

## 在 NixOS 里用（配合官方 sing-box 模块）

官方模块 `services.sing-box` 的 `package` 选项可指向本 fork：

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    sing-box-ref1nd.url = "path:/path/to/sing-box-ref1nd-flake";
  };

  outputs = { self, nixpkgs, sing-box-ref1nd, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        sing-box-ref1nd.overlays.default   # 注入 pkgs.sing-box-ref1nd
        ({ pkgs, ... }: {
          services.sing-box = {
            enable = true;
            package = pkgs.sing-box-ref1nd;
            settings = { /* 你的配置，支持 eBPF inbound、fallback 等 fork 特性 */ };
          };
        })
      ];
    };
  };
}
```

或不用 overlay，直接替换系统里的 sing-box：

```nix
nixpkgs.overlays = [
  (final: prev: {
    sing-box = final.sing-box-ref1nd;  # 全局替换为 fork
  })
];
```

## eBPF 说明

- 默认启用（`withEBPF = true`），构建为纯 Go（`CGO_ENABLED=0`）。
  BPF 字节码与绑定是 fork 预生成并提交在 `common/ebpf/internal/bpfgen/`，
  **不需要 clang / 内核头文件 / bpftool**，只额外引入 `github.com/cilium/ebpf`（纯 Go）。
- 运行时需要 **root 权限 + 内核 eBPF 支持**，可在 NixOS 上：
  ```bash
  sudo sing-box ebpf status   # 检查内核 eBPF 支持与活动状态
  ```
  eBPF inbound 配置参考 fork 文档：`docs/configuration/inbound/ebpf.md`。
- 想关掉 eBPF：把 flake.nix 里 `withEBPF = true` 改为 `false`（或直接
  `pkgs.callPackage ./pkgs/sing-box-ref1nd.nix { withEBPF = false; }`）。

## 备注

- 构建参数与 fork 官方构建一致：tags 取自 `release/DEFAULT_BUILD_TAGS_OTHERS`
  （另加 `with_ebpf`），ldflags 取自 `release/LDFLAGS`，`CGO_ENABLED=0` 静态构建。
- `doCheck = false` 与 nixpkgs 上游一致（sing-box 测试依赖网络环境）。
- 打包写法参考 nixpkgs 上游：`pkgs/by-name/si/sing-box/package.nix`。

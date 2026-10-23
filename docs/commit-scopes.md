# 本仓 scope 词表

`docs/commit-style.md` 要求"同一仓库内只允许一套词表"，但词表本身随仓库结构而定，不属于通用规范。这里冻结本仓的词表，新增 scope 前先确认它不是既有条目的同义词。

按使用频次排列：

| scope | 收敛自 | 覆盖范围 |
| --- | --- | --- |
| `pkgs` | packages, gui, cli | `pkgs/` 与 `flake.nix` 里的 overlay 定义 |
| `desktop` | plasma, sddm | `system/desktop-*.nix`、会话与显示管理器 |
| `niri` | — | `home/desktop/niri/` |
| `mango` | — | `home/desktop/mango/` |
| `noctalia` | — | `home/desktop/noctalia/` |
| `ghostty` | — | `home/programs/ghostty.nix` |
| `pi-agent` | pi-agent-desktop | `home/programs/pi-agent.nix`、`pkgs/pi-*-agent*.nix` |
| `system` | — | `system/` 下无更细归属的服务 |
| `hardware` | — | `system/hardware*.nix` |
| `boot` | plymouth | `system/boot.nix`、开机主题 |
| `audio` | — | `system/audio.nix`、`home/audio/` |
| `fonts` | — | `system/fonts.nix` |
| `input` | input-method | `system/input-method.nix` |
| `locale` | — | `system/locale.nix` |
| `network` | — | `system/network.nix` |
| `ssh` | — | `system/ssh.nix`、`home/programs/ssh.nix` |
| `users` | — | `system/users.nix` |
| `xdg` | — | `system/xdg.nix` |
| `nix` | — | `system/nix.nix`：镜像、清理、flake 设置 |
| `flake` | deps | `flake.nix`、`flake.lock` |
| `home` | — | `home/init.nix`、`home/core.nix` 等聚合层 |
| `fish` | — | `home/programs/fish.nix` |
| `git` | — | `home/programs/git.nix` |
| `jujutsu` | — | `home/programs/jujutsu.nix` |
| `direnv` | — | `home/programs/direnv.nix` |
| `zoxide` | — | `home/programs/zoxide.nix` |
| `gram` | zed | `home/programs/gram.nix` |
| `ollama` | — | `system/ollama.nix` |
| `secrets` | — | `home/secrets.nix`、`.sops.yaml`、`secrets/` |
| `just` | — | `justfile` |

## 新增 scope 的判据

按顺序问：

1. 已有 scope 能覆盖吗？能就别加。
2. 它指向本仓的一个目录或单一模块吗？不是就用更上层的 scope 或省略。
3. 它是软件名而改动其实属于打包吗？用 `pkgs`。
4. 它是 `home/programs/` 下的一个程序配置吗？可以直接用程序名，与本表同类项保持一致。

`just lint-msg` 只校验格式，不校验词表归属；词表一致性靠评审。改这张表时同步检查历史里是否已有同义 scope 需要改。

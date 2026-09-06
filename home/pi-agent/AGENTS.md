# 全局指令

## 本机事实

- NixOS 26.11 unstable，x86_64-linux，用户 `lynimbus`，配置仓 `~/dotfiles`（flake，主机名 `flakeos`）。
- 环境声明式管理：`~/.config` 下多是指向 `/nix/store` 的只读符号链接，手改无效且会被覆盖。要改就改仓里的 `.nix` 源文件再部署。
- home-manager 以 NixOS module 集成，用户层改动同样走 `nh os switch`。
- 交互 shell 是 nushell；我的 bash 工具跑的是 bash。给用户抄的命令按 nushell 语法写，管道里别默认 `2>&1`、`$()` 这类 POSIX 写法。
- 版本控制是 jj colocate（`.jj` 与 `.git` 并存），优先 jj。命令细节见 jj-usage / nix-usage skill。

## 工作方式

- 先查再答：涉及本机状态、版本、文件内容，用命令或读文件确认。
- 大文件先 `rg -n` 定位再分段读；批量统计或替换写脚本聚合。
- 不写代码注释，靠命名和结构自解释；要解释就写在回答里。
- 装包前先 `nix eval nixpkgs#<pkg>.version` 确认包名存在（包名常有出入）。
- 提交信息只写一行简洁的描述。

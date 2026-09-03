---
name: jj-usage
description: Jujutsu (jj) 版本控制工具专家（本机 jj 0.45.1，由 NixOS home-manager 提供）。当涉及 jj 命令（new/describe/commit/rebase/squash/absorb/split/undo/op/bookmark/git 等）、revset 查询语言、历史重写、工作副本快照与冲突解决、bookmark 与 Git 远程互操作、jj 配置时使用。
---

# Jujutsu (jj) 使用技能（源码级）

> 事实来源：本机 jj **0.45.1**（`/nix/store/hwifmhfi50y1595lhwiqsn7acppa7zdm-jujutsu-0.45.1/bin/jj`，由 home-manager 的 `programs.jujutsu` 提供）的 CLI 帮助（源自源码 clap 命令定义）+ 官方文档 docs.jj-vcs.dev/latest + 本机 `~/dotfiles` colocated 仓库。
> 版本坑：旧教程常教的 `git.push-bookmark-prefix`、`git.auto-local-bookmark` 两个配置键**早已移除**（0.42 起），分别被 `templates.git_push_bookmark`、`remotes.<name>.auto-track-bookmarks` 取代（见 §4.2）。别照搬旧文档。

---

## 0. 核心心智模型

### 0.1 工作副本自动快照——没有暂存区、没有 `add`
- jj **没有 staging area**。工作副本的改动自动就是当前 change（`@`）的一部分，新文件自动纳入（`jj status` 显示 `A a.txt`），无需 `git add` 对应物。
- 几乎每个命令走三步（官方文档原文）：**① snapshot 工作副本**（作为独立 operation 记录）→ **② 在内存中创建/修改 commit** → **③ 更新工作副本**到新 operation 指定的 commit。
- **tree 计算**：工作副本内容被提交为 commit 的 tree，与上一工作副本 commit 对比出 diff；文件冲突以「逻辑表示」存在 commit 里，扫描工作副本时解析冲突标记重建冲突状态。
- `--ignore-working-copy`：跳过 snapshot 与工作副本更新，看到可能过期的 `@`；`--at-operation` 隐含此选项（适合 prompt/脚本里要稳定视图时）。
- **stale working copy**：`.jj/working_copy/` 记录上次更新到的 operation ID，不匹配即 stale，用 `jj workspace update-stale` 修复（`snapshot.auto-update-stale = true` 可自动修）。

### 0.2 change ID 与 commit ID——稳定标识 vs 内容哈希
- **change ID**：32 字符（如 `nklrskzsqoztrnryyuwuluonlsuvusou`），底层 128 bit，显示用「z-k」反向字母表（hex `0-9a-f` → `z-k`，源码 `object_id.rs`），故只含 k-z 的小写字母、无数字——标识「一个变更的演化链」，跨 rebase/squash/amend **稳定**。
- **commit ID**：40 位 hex（与 Git SHA-1 同源），标识具体快照，重写即变。
- 实测：`jj rebase -r @ -B @-` 后 change 保持 `mlxlpnmmqnsyyvmkqwlmmqqotxtyplwu` 不变，commit 从 `fbab091a` 变 `855c1050`。`jj evolog` 展示该 change 各版本演化。
- commit 对象含：parents、tree、description、author、committer（各带时间戳）。root commit 是 commit ID 全 `0`、change ID 全 `z` 的虚拟提交。
- `jj log` 默认模板两列显示——左 change ID（短，默认 12 字符），右 commit ID（短）；长度由 `format_short_change_id`/`format_short_commit_id` 模板别名控制。
- **引用习惯**：日常用 change ID 短名（本机实际用 8 位）；divergent change 用 `<change ID>/<offset>`（如 `/0` `/1`）；歧义时改用 commit ID 唯一前缀（或 `commit_id(x)` 强制）。

### 0.3 操作日志（op log）——一切可撤销
- 所有命令都是原子 **operation**：op 对象存 `.jj/repo/op_store/`（operations/views），heads 指针在 `.jj/repo/op_heads/`（git backend 下兼存于 git refs `refs/jj/keep/`）。operation 含：view 快照（各 bookmark/tag/Git ref 指向、heads 集合、各 workspace 工作副本 commit）+ 父 operation 指针 + 元数据（时间戳、user、hostname、描述）。
- `jj undo` 回退到父 operation（连续 undo 逐级回退）；`jj redo` 反向；`jj op restore <op>` 恢复到某 operation（`--what repo|remote-tracking` 选范围）；`jj op log` 可视化（`@` 指当前 operation，支持 `@-`/`@+`）。
- op log 允许无锁并发（divergent operations），冲突以 change 分叉形式暴露。
- op log **不自动裁剪**（无 `jj op gc`），长期仓库会变大，属已知现状。

### 0.4 bookmark——不是 branch，不自动前进
- bookmark 是命名指针，可任意移动，**没有「当前 bookmark」概念**（与 git branch 根本不同）。
- **不自动前进**：commit 被重写（rebase 等）时 bookmark 自动跟随，但正常新 commit **不会**推进 bookmark——需要时手动 `jj bookmark move`。只在要 push 时才创建 bookmark。
- **tracked**：本地 bookmark 与同名远程 bookmark 关联（`jj bookmark track foo --remote=origin`），fetch 时远程变化传播到本地；本地名必须与远程同名。
- **untracked**：远程 bookmark 只记录「最近看到的位置」（`main@origin` 这种引用就是记录位置），不生成本地 bookmark。
- **推拉安全**：push 前检查远程实际位置 == 记录位置（类似 `git push --force-with-lease`），不一致则拒绝。

### 0.5 冲突是一等公民
- 冲突以**逻辑表示存进 commit**（不是标记文本），所以冲突后的 commit 也能继续 rebase，不会出现嵌套冲突标记。`jj rebase` 遇冲突**不失败**，直接把冲突记进新 commit。
- 工作副本检出冲突 commit 时以标记物化，默认 `diff` 风格：`<<<<<<< conflict 1 of 1` / `%%%%%%% diff from: <base>` / `+++++++ <side>` / `>>>>>>>`；直接编辑标记即可解决，**可部分解决**。`ui.conflict-marker-style` 可换 `snapshot` 或 `git`（git 风格仅支持 2 侧，超则回退 snapshot）。
- **解决流程**（官方推荐）：`jj new <conflicted>` 在工作副本上解决 → `jj diff` 检查 → `jj squash` 把解决内容并入原 commit；`jj resolve` 用外部 3-way merge tool（`ui.merge-editor`，`:ours`/`:theirs` 选侧）；`jj restore` 可选单侧。
- **文件层 vs 提交层**：冲突在文件层（tree 中文件内容为多侧+base），`conflicts()` revset 找含冲突文件的 commit；bookmark 也有自己的冲突（本地与远程各自更新 → `main??` 显示，`jj bookmark move` 解决，冲突 bookmark 无法 push）。

---

## 1. revset 语言

### 1.1 符号与运算符
符号：`@`（当前 workspace 工作副本）、`<workspace>@`、`<name>@<remote>`（远程 bookmark/tag）、commit ID / change ID 唯一前缀、引号包裹防解析。解析优先级：tag → bookmark → commit/change ID。

运算符（从强到弱）：

| 运算符 | 含义 |
|---|---|
| `f(x)` | 函数调用 |
| `x-` / `x+` | parents / children（`x--`、`x++` 迭代） |
| `p:x` | 模式（`p:"foo"` 匹配描述前缀） |
| `x::` | x 的后代（含自身）；`::x` = 祖先含自身（即 `root()::x` 简写） |
| `..x` | 祖先含自身但**排除 root** |
| `x::y` | x 的后代 ∩ y 的祖先（≈ git `--ancestry-path`） |
| `x..y` | y 的祖先，排除 x 的祖先（≈ git `x..y`） |
| `::` / `..` | 全部可见（含 / 不含 root） |
| `~x` | 取反 |
| `&` | 交集 |
| `~`（二元） | 差集 |
| `\|` | 并集 |

坑：`(A|B)..` ≠ `A..|B..`，等于 `A.. & B..`（`..` 在左侧把并集转交集）。

### 1.2 函数清单（分类）
- **图导航**：`parents` `children` `ancestors` `descendants` `first_parent` `first_ancestors` `reachable(srcs,domain)`（如 `reachable(@, mutable())` 找当前改动栈）`connected(x)`（=`x::x`）`heads` `roots` `latest(x,[n])` `fork_point` `merge_point` `merges` `forks` `exactly(x,n)` `bisect`
- **命名引用**：`all()` `none()` `bookmarks(pattern)` `remote_bookmarks(name,remote=)` `tracked_remote_bookmarks()` `untracked_remote_bookmarks()` `tags()` `remote_tags()` `visible_heads()` `root()` `working_copies()`
- **元数据过滤**：`description()` `subject()` `author()` `author_name()` `author_email()` `author_date()` `mine()` `committer()` `committer_date()` `signed()` `empty()` `conflicts()` `divergent()`
- **文件**：`files(fileset)`（目录名匹配子目录；`.` 需引号 `files(".")`）`diff_lines()` `diff_lines_added()` `diff_lines_removed()`
- **工具**：`change_id()` `commit_id()` `present()` `coalesce()` `at_operation(op,x)`

### 1.3 字符串与日期模式
字符串默认 glob，可用前缀 `exact:`/`glob:`/`regex:`/`substring:`，`-i` 大小写不敏感，`~ & |` 组合。日期用 `after:`/`before:`，支持 `2024-02-01`、`2 days ago`、`yesterday 5pm`。

### 1.4 内置别名（可被 revset-aliases 覆盖）
- `trunk()`：默认远程默认 bookmark 的 head，回退 upstream/origin 的 main/master/trunk，无则 `root()`
- `builtin_immutable_heads()` = `trunk() | tags() | untracked_remote_bookmarks() | untracked_remote_tags()`（0.45 起含 untracked_remote_tags()）
- `immutable_heads()` = `builtin_immutable_heads()`；
- `immutable()` = `::(immutable_heads() | root())`
- `mutable()` = `~immutable()`
- `builtin_log()` = `present(@) | ancestors(immutable_heads().., 2) | trunk()`

### 1.5 典型查询
```bash
jj log -r 'mine() & committer_date(after:"7 days ago")'   # 最近 7 天我改的
jj log -r 'files(foo/bar.txt)'                            # 含某文件的提交
jj log -r 'trunk()::'                                     # 主干上的提交
jj log -r 'remote_bookmarks()..'                          # 未推送的提交（无远程时为空）
jj log -r 'reachable(@, mutable())'                       # 当前改动栈
jj log -r 'mine() & ~::trunk()'                           # 我未合入主干的提交
# git 等价：@- ≈ git log -1 HEAD；::@ ≈ git log；tags()|bookmarks() ≈ --simplify-by-decoration
```

---

## 2. 数据模型（.jj 内部结构）

### 2.1 仓库布局与 backend
- jj 默认用 **git backend**：commit/tree 用 Git 对象格式存储，天然与 git 互操作。`.jj/repo/store/` 下 `type` 标记 backend、`git_target` 指向 git 目录。
- **colocated 仓库**（默认，`git.colocate = true`）：`.jj` 与 `.git` 并存共享一个工作目录；git HEAD 与 jj 工作副本 parent 同步（op log 里有「import git head」操作）。
- 纯 jj（非 colocated）：工作副本内容导出到 `.git` 之外，`.git` 仅作远程互操作缓存。
- `.jj/working_copy/` 记录工作副本状态（stale 判定用，见 §0.1）；`.jj/repo/op_heads/` 存 op log。

### 2.2 commit 对象与 change ID
- commit = parents + tree + description + author + committer（各带时间戳），另带稳定的 change ID（32 字符 z-k 字母表）与内容哈希 commit ID（40 hex）。
- 重写（rebase/squash/amend）产生新 commit ID，但保留 change ID——这就是「历史可安全重写」的机制基础。

### 2.3 op log 存储
- operation 对象含 view 快照 + 父 operation 指针 + 元数据；`jj op log` 可视化，`--at-operation` 可回看任意历史状态（隐含 `--ignore-working-copy`）。

---

## 3. CLI 速查（0.45.1，47 个顶层命令）

### 3.1 全局选项（任何命令可用）
```
-R/--repository <path>    # 指定仓库（默认向上找最近的 .jj/）
--ignore-working-copy     # 不 snapshot、不更新工作副本（看可能过期的 @）
--at-operation/--at-op <op>  # 以某 operation 时的视图操作（隐含 ignore-working-copy；--at-op=@ 不合并 divergent）
--ignore-immutable         # 允许改 immutable（trunk/tag 等，危险）
--no-integrate-operation   # 本次操作不入 op log，打印 op ID（可用 jj op integrate 补录）
--config <k=v> --config-file <path>  # 临时覆盖配置
--quiet --no-pager --debug --color
```

### 3.2 日常操作
| 命令 | 作用与要点 |
|---|---|
| `jj new [revs]` | 建空 change 并默认编辑它（`--no-edit` 不切工作副本）；多参数创建 merge（`jj new @ main`）；`-A/-B` 在图里插入到前/后 |
| `jj describe [rev]` | 编辑描述/元数据，默认 `@`；`-m` 直接写、`--stdin`；本机常用 `jj describe --editor -r <change>` |
| `jj commit -m ...` | **= describe + new 的组合**（help 原文）；带 `-i` 或路径时是「把部分改动留在当前 commit、其余移到新 commit」 |
| `jj edit <rev>` | 把指定 revision 设为工作副本 commit（help 建议优先 `new`+`squash`） |
| `jj log` | `-r`/`-n`/`--reversed`/`-G`（无图）`-T` 模板/`-p` 补丁/`--count`；默认只显示 mutable 区（`revsets.log`，默认 `builtin_log()`） |
| `jj status` | 工作副本改动、冲突文件、冲突 bookmark |
| `jj diff` | `-r`（对比合并 parents）/`-f`/`-t`；无参默认 `-r @`；`--stat --types --name-only --git --color-words --tool` |
| `jj show [rev]` | 元数据 + diff，默认 `@`；`--no-patch` |
| `jj evolog [rev]` | 展示 change 的演化史；模板关键字是 `CommitEvolutionEntry` 的（如 `commit`），**不是** `commit_id` |

### 3.3 历史修改
| 命令 | 作用与要点 |
|---|---|
| `jj rebase` | `-s`（源+其后代）/`-b`（整条分支 `(dst..src)::`）/`-r`（仅该 rev，后代自动补位）；目标 `-o`/`-A`/`-B`；`-o` 重复=创建 merge；`--skip-emptied` 空结果自动 abandon；默认 `-b @` |
| `jj squash` | 把改动移进另一 commit；默认 `@`→parent；`-f/--from` `-t/--into`；`-i` 交互选块；`-k` 保留空源；源变空自动 abandon；`-u` 用目标描述 |
| `jj split` | `-i` 交互分割；`-r` 指定 rev；`-p` 平行分割；`-o/-A/-B` 提取到别处；`-m` 描述 |
| `jj absorb` | 把源 change 的改动按行分派到最近的 mutable 祖先（`-f` 源、`-t` 目标默认 `mutable()`）；`-i` 交互选 hunk（0.44+）；全吸收且无描述则源 abandon；`jj op show -p` 可审查 |
| `jj abandon` | abandon 并把后代 rebase 到 parent(s)；`--retain-bookmarks`、`--restore-descendants`；工作副本被 abandon 时自动给新空 commit |
| `jj duplicate` | 复制 commit（新 change ID）；默认保留描述（`templates.duplicate_description` 可加 "cherry picked from"） |
| `jj restore` | `--from`/`--into` 恢复路径；`-c/--changes-in` 撤销某 rev 相对 parents 的改动（默认行为）；无参 ≈ abandon 但保留空 commit 与元数据 |
| `jj metaedit` | 不改内容改元数据；`--update-change-id` `--update-author` `--author` `--author-timestamp` `--force-rewrite`；`JJ_USER`/`JJ_EMAIL` 可注入 |
| `jj undo` / `jj redo` | 逐级回退/前进 operation（见 §0.3） |
| `jj diffedit` | diff 编辑器直接改 `-r`/`--to` 的内容；`--restore-descendants` 保留内容而非 diff |
| `jj converge` | 0.45+，自动收束 divergent change：按 change ID 分组，启发式合并出单个替代 commit，后代自动 rebase；启发式不确定时交互询问（`--no-interactive` 改警告退出） |
| 其他 | `jj parallelize`（变 siblings）、`jj arrange`（交互排序 TUI）、`jj prev/next`（`--edit` 切工作副本）、`jj revert`（应用反向）、`jj simplify-parents`、`jj interdiff`、`jj sign`/`jj unsign`（签名管理）、`jj bisect run`（二分定位）、`jj run`（对一组 rev 跑命令）、`jj fix`（格式化） |

### 3.4 bookmark 管理
| 命令 | 要点 |
|---|---|
| `jj bookmark create <name>` | 在 `@`（或 `-r`）建 bookmark |
| `jj bookmark set <name> -r <rev>` | 指向某 rev（`-B` 允许后退） |
| `jj bookmark move <name> --from <old> --to <new>` | 移动（解决 bookmark 冲突、推进主干用） |
| `jj bookmark advance` | 推进 bookmark：目标 `to` 由 `revsets.bookmark-advance-to`（默认 `@`）决定，来源 `from` 由 `revsets.bookmark-advance-from`（默认 `heads(::to & bookmarks())`）决定 |
| `jj bookmark delete/forget` | 删除（`delete` 传播到远程；`forget` 只本地） |
| `jj bookmark rename` | 重命名 |
| `jj bookmark list` | `-a` 含所有远程、`-t` tracked、`-c` 冲突 |
| `jj bookmark track/untrack <name> --remote=<r>` | 建立/解除与远程 bookmark 的跟踪 |
| `jj tag ...` | 0.44 起 tag 与 bookmark 同待遇：`set`（建/改）/`delete`/`list`/`track`/`untrack`；fetch 到的 tag 默认 tracked，tracked tag 默认随 push |

### 3.5 git 互操作
| 命令 | 要点 |
|---|---|
| `jj git clone <url> [dest]` | 默认 `--remote origin`、**默认 `--colocate`**；`-b`/`-t`/`--depth`/`--object-hash` |
| `jj git init [--git-repo <path>]` | 新仓库；`--git-repo` 复用已有 git repo |
| `jj git fetch` | `-b/-t/--tracked/--remote/--all-remotes`；默认 remote 取 `git.fetch` 否则 origin；0.44 起 tag 与 bookmark 同样抓取（`<name>@<remote>`，同名本地 tag 自动 track） |
| `jj git import` / `jj git export` | colocated 下**默认自动做**；0.44 起显式跑在 colocated 仓默认禁用（有竞态，本就 no-op） |
| `jj git push` | 默认推指向 `remote_bookmarks(remote=<remote>)..@` 的 tracked bookmark/tag；`-b`/`-t`/`--all`（0.44 起含 tag）/`--tracked`/`--deleted`；`-c/--change` 生成 `push-<change_id短>` bookmark；`--named name=rev`；`--allow-conflicts`（0.44+）；`--dry-run`；**安全检查类 force-with-lease**（只比对记录位，允许 sideways 移动，见 §7.11） |
| `jj git remote` | `add/list/remove/rename/set-url` |

---

## 4. 配置（config）

### 4.1 文件位置优先级（后覆盖前）
内置默认（只读，`jj config list --include-defaults` 可见）→ 系统 `/etc/jj/config.toml`、`/etc/jj/conf.d/*.toml` → 用户 `~/.config/jj/config.toml`（`JJ_CONFIG` 环境变量可整体替换）→ 仓库级（`jj config edit --repo`，**出于安全不在 repo 内**，在 `~/.config/jj/repos/<repo-path-hash>/config.toml`）→ workspace 级 → 命令行 `--config`/`--config-file`。
JSON Schema 提示：文件头加 `#:schema https://docs.jj-vcs.dev/latest/config-schema.json`。

> **本机限制（NixOS）**：`~/.config/jj/config.toml` 由 home-manager 的 `programs.jujutsu.settings` 托管，是指向 `/nix/store` 的**只读符号链接**。因此 **`jj config set --user` / `jj config edit --user` 会写失败**。改用户级配置的惟一途径是改 `~/dotfiles/home/flakeos.nix` 里的 `programs.jujutsu.settings` 然后 `just switch`。
> 仍可写的层：仓库级 `jj config set --repo <key> <val>`（落在 `~/.config/jj/repos/<hash>/`，不受托管；`jj config gc` 可清理已删仓库的残留）、临时 `--config`、`JJ_CONFIG` 指到其他文件。0.45 起 `jj config {edit,set,unset}` 支持 `--file <PATH>` 精确指定文件，`--user` 不再交互询问、直接写第一个加载的用户配置文件——但只读符号链接照样写不进。同理 `~/.config/git/config` 也是只读，`git config --global` 不可用，用 `git config --local` 或改 nix 配置。

### 4.2 关键配置键
```toml
[user]
name = "lynimbus"
email = "128837704+lynimbus@users.noreply.github.com"   # JJ_USER/JJ_EMAIL 环境变量优先

[ui]
default-command = "log"        # 本机已设；jj 无参数时默认跑的命令
editor = "nvim"                # 本机已设；优先级 $JJ_EDITOR > ui.editor > $VISUAL > $EDITOR（默认 nano）
diff-editor = "..."            # jj split/squash -i 用；--tool 临时覆盖
merge-editor = "mergiraf"      # 本机已设；jj resolve 用
conflict-marker-style = "diff" # diff|snapshot|git
pager = "delta"                # 本机已设（delta 兼做分页与高亮）；JJ_PAGER 覆盖；PAGER 被忽略

[git]
push = "origin"                # 默认推送 remote（只能单值）
fetch = ["origin"]             # 默认 fetch remote（可列表）
colocate = true                # 默认，colocated 模式
abandon-unreachable-commits = true
private-commits = "description(glob:'wip:*') | description(glob:'private:*')"  # 本机已设：禁止推送的 commit（revset）
sign-on-push = true            # 本机已设；配合下方 [signing] 的 ssh 后端，push 时真签名
write-change-id-header = true  # 导出到 git 的 message 写 Change-Id 头

[remotes.origin]
fetch-bookmarks = "..."        # 抓取哪些 bookmark（glob）
fetch-tags = "..."             # 抓取哪些 tag
auto-track-bookmarks = "..."   # 如 "alice/*" 只自动 track 自己前缀
auto-track-created-bookmarks = false

[templates]
git_push_bookmark = '"push-" ++ change_id.short()'   # 取代旧 git.push-bookmark-prefix

[snapshot]
auto-track = "..."             # fileset，控制自动 track 哪些新文件
max-new-file-size = 1048576    # 默认 1MiB，0 禁用
auto-update-stale = false

[revset-aliases]
"immutable_heads()" = "tags()" # 本机已设：收窄为只认 tag，已推送历史默认可重写（见 §5.1）
"trunk()" = "..."              # 可覆盖内置

[signing]
behavior = "keep"               # drop|keep|own|force（默认 keep）
backend = "ssh"                # 本机已设（gpg|gpgsm|ssh|none；本机无 gpg）
key = "/home/lynimbus/.ssh/id_ed25519"  # 本机已设；ssh 后端指向私钥路径
```
- 命令别名：`[aliases]`（单命令；多命令用 `util exec`）；模板别名 `[template-aliases]`（如 `format_short_id`）。
- 条件配置：`[[--scope]]` + `--when.repositories/workspaces/hostnames/commands/platforms/environments`。

---

## 5. 本机工作流（~/dotfiles，NixOS）

### 5.1 现状
- **仓库**：`~/dotfiles`（NixOS flake 配置仓，host `flakeos`），**colocated**（`.jj` + `.git` 并存，git backend）。旧的 `~/nix` 仓已随迁移到 NixOS 而废弃。
- **jj 由 nix 提供**：`programs.jujutsu.enable = true`（home-manager module），版本 0.45.1。jj 本体升级跟随 `nix flake update`，不存在单独升级 jj 的概念。
- **配置声明式托管**：`~/.config/jj/config.toml` 是 `/nix/store` 只读符号链接（见 §4.1 的本机限制）。当前声明（`home/flakeos.nix`）：`user.name`/`user.email`（从 flake.nix 顶层变量下传）、`ui.default-command = "log"`、`ui.editor = "nvim"`、`ui.pager = "delta"`、`ui.merge-editor = "mergiraf"`、`git.sign-on-push = true`、`git.private-commits = "description(glob:'wip:*') | description(glob:'private:*')"`、`revset-aliases."immutable_heads()" = "tags()"`。
- **已推上 GitHub**：remote `origin = git@github.com:lynimbus/dotfiles.git`，本地 bookmark `main` 已 track `main@origin`，`trunk()` 解析到 `main@origin`；日常引用仍多用 change ID 短名（8 位）。
- **重写已推送历史是本机常态**：`immutable_heads()` 被刻意收窄为 `tags()`，已推送的 main 历史全部 mutable；重写后 `jj git push` 做 sideways 移动即可同步（见 §7.11）。
- **签名**：`signing.backend = "ssh"` + `signing.key = ~/.ssh/id_ed25519`（本机无 gpg），配合 `sign-on-push = true`，push 时给被推送 commit 附加 SSH 签名（commit ID 变、change ID 不变，输出 `Updated signatures of N commits`）。GitHub 要显示 Verified 需把该公钥另加为 **signing key**（与 auth key 是两个列表）。
- 提交风格：模块前缀为主（`flakeos: ...`、`home: ...`、`nix: ...`），中英混用；**LLM 发起的提交带 `llm: ` 前缀**（AGENTS.md 约定），用户自己的提交不动。

### 5.2 日常节奏（符合 jj「先干活后 describe」风格）
```bash
jj status                  # 看工作副本改动（默认命令是 log，但 st 常用来触发 snapshot）
jj new -r <change>         # 建空提交
jj describe --editor -r <change>            # 写描述
jj abandon --retain-bookmarks -r <change>   # 弃提交
jj log                     # 默认命令，看历史
jj undo / jj op log        # 搞砸了回退
jj git push                # main 已 tracked，默认即推；重写过的历史 sideways 推（见 §7.11）
```
- `@` 经常处于「无 description、带未完成改动」状态，这是 jj 正常态，不必急着 describe。
- 描述以 `wip:`/`private:` 开头的 commit 命中 `git.private-commits`，push 会被拒。

### 5.3 与 NixOS 交叉的几个关键点
- **`flake.lock` 与对应配置改动放同一个 commit**。锁文件单独提交会让「哪一代对应哪份配置」失去对应关系，排查回归时极痛苦。
- **`nix build`/`nixos-rebuild` 看的是工作副本当前内容，不是 commit**。jj 无暂存区，改完直接 `just switch` 就部署了未提交的改动——这是特性不是 bug，但意味着**部署成功后要记得提交**，否则下次 `jj new` 会把已部署的改动带进新 change。
- **`warn-dirty = false`**（已写进 `nix.settings`）：jj 工作副本常脏，否则每次 flake 操作都告警。
- **flake 只看得到 git 跟踪的文件**：新建的 `.nix` 文件若没被 git 跟踪，`nix build` 会报 `path does not exist`。jj 会自动 track 新文件并在 snapshot 时写入 git index，所以先跑一次 `jj st` 就能解决——**这是 colocated 仓新增文件后 `nix build` 报路径不存在的标准解法**。
- **不要把 `result` 符号链接提交**：`nix build` 默认建 `./result`（jj 会自动 track）。要么用 `--no-link`，要么写进 `.gitignore`。

### 5.4 GitHub 同步（origin 已配置）
- remote：`origin = git@github.com:lynimbus/dotfiles.git`；`main` 已 tracked，日常 `jj git push` 即可。
- 重写已推送历史后直接 push：jj 报 `bookmark: main [move sideways from ... to ...]`，lease 检查通过即成功（实测 `--dry-run` 验证过）。
- 若他机推过导致记录位过期：先 `jj git fetch`，再决定 rebase 还是覆盖。
- 新建 bookmark 推送：`jj git push --bookmark <name>`（未 track 的 bookmark 会自动 track）。
- 敏感信息：本仓目前无密钥/token，但日后若引入 sops-nix/age 要先确认密钥本体不入仓（只入密文）。

---

## 6. git → jj 对照表（心智迁移）

| git | jj | 要点 |
|---|---|---|
| `git add` | 不需要 | 工作副本自动跟踪 |
| `git add -p` | `jj split -i` | 交互挑选 |
| `git commit -m` | `jj commit -m`（或 `jj describe -m` + `jj new`） | 无 staging |
| `git commit --amend` | `jj describe`（描述）/ `jj squash`（内容） | change ID 不变 |
| `git commit --allow-empty` | `jj new` | |
| `git checkout -b <n>` | `jj bookmark create <n>` | bookmark 可选 |
| `git checkout <branch>` | `jj new <bookmark>` | |
| `git switch` | `jj edit <bookmark>` | |
| `git branch -d/-m` | `jj bookmark delete/rename` | |
| `git rebase -i` | `jj rebase` / `jj squash` / `jj split` | 用命令代替交互编辑器 |
| `git rebase --onto` | `jj rebase -r <rev> -d <dest>` | |
| `git cherry-pick` | `jj rebase -r <rev> -d @` | |
| `git rebase --abort` | `jj undo` | 无 rebase 中间态 |
| `git bisect` | `jj bisect run -- <cmd>` | 对 revset 二分 |
| `git merge` | `jj new <base> <branch>` | jj 总是显式 merge commit（无 fast-forward） |
| `git merge --squash` | `jj squash -r <branch>` | |
| `git fetch` | `jj git fetch` | |
| `git pull` | `jj git fetch` + rebase/merge | 两步 |
| `git push` | `jj git push --bookmark <name>` | 必须指定 bookmark |
| `git push --force` | 无 `--force`（push 内置 force-with-lease 检查） | |
| `git stash`/`pop` | `jj new` / `jj squash -r <stash>` | stash 概念消失 |
| `git tag` | `jj tag set`（或 `jj bookmark create`） | 0.44 起 tag 一等公民 |
| `git reset --soft HEAD~1` | `jj edit @-` | |
| `git reset --hard HEAD~1` | `jj abandon @` | |
| `git checkout -- <f>` | `jj restore <f>` | |
| `git revert` | `jj revert -r <rev> --onto @` | |
| `git reflog` | `jj op log` | 更全 |
| `git blame` | `jj file annotate` | |
| `git log --follow` | `jj log <file>` | 默认 follow rename |
| `git diff <a> <b>` | `jj diff --from <a> --to <b>` | |
| `git diff --cached` | 不适用 | 无 staging |
| `git commit --fixup`+autosquash | `jj squash --into <id>` | 后代自动 rebase |

四大心智差异：无 staging / 无「当前分支」概念 / 后代自动 rebase / 冲突是一等公民。

---

## 7. 常见坑速查（源码级教训）

1. **push 之后不要 `jj undo`**——会产生过期的远程状态信息。push 是边界，之后只做 forward fix（`jj redo`，或 `jj git fetch` + `jj bookmark move` 重新对齐远程）。
2. **bookmark 不自动前进**：新 commit 不会推进 bookmark（和 git branch 完全相反），要手动 `jj bookmark move`；只在要 push 时才建 bookmark。
3. **不要混用 git 和 jj 命令**（colocated 仓库会状态不一致）：一个会话只用一种工具；用了 git 之后必须 `jj git import`。
4. **冲突解决提交不可 squash 回祖先**：下游提交是对「已解决树」写的，collapse 后全部重新冲突。解决提交在两个提交之间且有下游依赖时，几乎总是错的，保留它并 `jj describe` 改名即可。
5. **conflicted bookmark（`??`）无法 push**：用 `jj bookmark move <name> --to <commit>` 解决。
6. **重写已推送历史仍然危险**：jj 只是让恢复更容易，不是没有后果。
7. **`git.push-bookmark-prefix` / `git.auto-local-bookmark` 已移除**（0.42 起）：分别用 `templates.git_push_bookmark`、`remotes.<name>.auto-track-bookmarks`。旧教程别照抄。
8. **divergent change（`/0` `/1` 偏移）**：远程 rebase 导入新 commit_id，旧版仍可见——0.45+ 先试 `jj converge`（启发式自动合并）；手动则 `jj abandon` 旧版，多个逐个清理；引用歧义时改用 commit ID。
9. **stale working copy 报错**：`jj workspace update-stale`（或 `jj status` 触发 snapshot）。
10. **文件在 jj 之外删除不显示在 diff 里**：`jj status` 触发一次 snapshot。
11. **push 被拒先看原因**：jj 的 lease 检查只比对「远程实际位置 == 上次 fetch 记录位」，**不要求 fast-forward**——重写已推送历史后的 sideways 移动能直接推（本机常态）；被拒说明远程被别人动过，`jj git fetch` 后再决定 rebase 或覆盖。
12. **`jj log` 太刷屏**：`-n 10`、`-r ::@`，或 `jj config set revsets.log '::@ | @::'`。
13. **`(A|B)..` 陷阱**：revset 里 `..` 在左侧把并集转交集，`(A|B)..` = `A.. & B..`，不是 `A.. | B..`。
14. **`jj evolog` 模板关键字不是 `commit_id`**：用 `CommitEvolutionEntry` 的字段（如 `commit`）。
15. **`--at-operation` 隐含 `--ignore-working-copy`**：脚本里想同时看历史状态 + 工作副本时注意。
16. **op log 不自动裁剪**：长期仓库会变大；可用 `jj op abandon` 手动裁剪旧 operation（无 `jj op gc`）。
17. **GitHub auth 失败**：jj 复用 Git 凭据系统，修 `git credential.helper` 即修 jj。
18. **colocated 太混乱的出路**：删 `.git`（转纯 jj）或删 `.jj`（转纯 git），二选一，别两套混着维护。
19. **sign-on-push 会在 push 时重写被推送的 commit**（附加签名，commit ID 变、change ID 不变），push 前后 commit ID 对不上是预期。若 `signing.backend` 为默认 `none` 则静默不签名（无 `gpgsig` 头）也不报错——本机已配 `ssh` 后端避免此情况。

---

## 8. 排查套路

1. 搞不清当前状态：`jj status` + `jj log -n 10` + `jj bookmark list -a`。
2. 想撤销某步：`jj op log` 找到对应 operation → `jj undo` 逐级回退，或 `jj op restore <op>`。
3. 想看懂某 change 怎么来的：`jj evolog <change>` + `jj op show -p <op>`。
4. 冲突：`jj log -r conflicts()` 定位 → §0.5 的 `new` + 编辑 + `squash` 流程。
5. 要查「改了某文件的历史」：`jj log -r 'files(<path>)'`；查内容 `jj file annotate <path>`。

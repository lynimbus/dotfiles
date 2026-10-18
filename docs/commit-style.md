# 提交信息规范

本规范是 [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)（MIT）的一个落地档：前者的 16 条 `MUST` 全部保留，另加一小组可机器校验的附加规则。任何仓库都可以直接采用；与本文冲突时以 Conventional Commits 原文为准。

## 格式

```
<type>[(<scope>)][!]: <description>

[body]

[footer(s)]
```

- header 必填，**单行**，`type` 与 `:` 之间无空格，`:` 之后固定一个空格。
- body 与每个 footer 之前各留**一个空行**；两者都可以省略。
- 默认只写 header。只有"为什么这么做"或"影响面"靠 header 表达不了时才加 body。
- 全文按纯文本处理，不用 Markdown 标题、列表符号或代码块。

## type

以下 11 种，取不到合适的就说明这次改动该拆成多个提交：

| type | 用于 |
| --- | --- |
| `feat` | 新增功能或能力 |
| `fix` | 修复缺陷 |
| `build` | 构建系统、打包、依赖版本 |
| `chore` | 杂务：升级锁文件、清理、仓库配置 |
| `ci` | 持续集成与流水线 |
| `docs` | 文档与注释 |
| `perf` | 性能优化，不改变行为 |
| `refactor` | 结构重排，不改变行为 |
| `revert` | 回退既有提交，footer 用 `Refs:` 指向被回退的提交 |
| `style` | 格式化、空白、命名，不影响语义 |
| `test` | 测试及其数据 |

`feat` 与 `fix` 的语义严格绑定 SemVer（`MINOR` / `PATCH`），其余类型不产生版本影响。破坏性改动用 `!` 或 `BREAKING CHANGE:` 表达，与 type 无关。

## scope

可省略。省略是默认选择：改动已被 type 完整表达时不要再加 scope。

使用时有四条约束：

1. 小写名词，只允许 `[a-z0-9.+-]`，用 `-` 而非空格或下划线。
2. 指向代码区段，即目录或模块名，不指向人名、issue 号或情绪。
3. **同一仓库内只允许一套词表**。同义 scope 出现即视为缺陷，收敛到其中一个。
4. 一次提交只写一个 scope。跨多个区段时省略 scope，或拆成多个提交。

推荐初始词表，按仓库实际结构增删，一旦定下就不再引入同义词：

```
build   用户与系统构建、打包定义
system  系统级服务与硬件
home    用户环境聚合
desktop 桌面环境与显示管理器
nix     包管理与 nix 配置
pkgs    打包源码与覆盖
ci      流水线
docs    文档
```

示例：`feat(pkgs): 新增 obs-studio 打包`，而非 `feat(obs-studio): ...`（软件名不是区段）或 `feat(GUI): ...`（大写）。

仓库一旦定下自己的词表，就把它写进一份仓内清单（如 `docs/commit-scopes.md`），新建 scope 前先对照，避免同义词扩散。

## description

- 用祈使句描述"这次提交做了什么"，不是"我做了什么"或"文件被改成了什么"。
- 不超过 100 字符；建议控制在 60 以内，让 `git log --oneline` 与 jj 的默认视图不折行。
- **不加结尾句号**，不加表情符号。
- 允许中文或英文，但同一仓库保持一致。若用中文，`type` 与 `scope` 仍保持小写英文，否则无法被工具解析。
- 具体优于笼统：写"修复 QQ 在 niri 上无法使用 fcitx5"，不写"修复输入法问题"。

## 破坏性改动

用 `!` 紧跟 type 或 scope，或加 `BREAKING CHANGE:` footer，两者可同时使用：

```
feat(api)!: 移除 v1 端点

BREAKING CHANGE: 调用方需改用 /v2，v1 已下线
```

`!` 出现时，description 本身就要说清楚破坏点，不能只写"调整接口"。

## footer

沿用 git trailer 格式：`Token: value`，token 用 `-` 代替空格。

```
Refs: #123
Reviewed-by: Z
BREAKING CHANGE: 配置文件中的 extends 键改为用于扩展其他配置文件
```

`BREAKING CHANGE` 必须大写，`BREAKING-CHANGE` 与之等价。其余 token 大小写不敏感。

## 工具链

- 生成：模型或脚本产出的信息必须能被 §校验 的校验器接受。
- 校验：见 `docs/lint-commit-message.sh`，可接 `commit-msg` 钩子或 CI。
- 历史整理：批量改写已提交的信息属于重写历史，改动会传播到所有下游克隆，执行前确认仓库无人依赖这些 hash。

## 校验

`docs/lint-commit-message.sh` 实现本文全部可判定规则：

```sh
docs/lint-commit-message.sh .git/COMMIT_EDITMSG
git log -1 --format=%B | docs/lint-commit-message.sh
```

接成钩子：

```sh
mkdir -p .git/hooks
ln -sf ../../docs/lint-commit-message.sh .git/hooks/commit-msg
chmod +x docs/lint-commit-message.sh
```

校验器与本文的分工：校验器只判定 §type/§scope/§description 的机械部分（type 枚举、小写、长度、结尾句号、空行）。"祈使句""具体优于笼统""scope 是否指向区段"这类判断由评审承担。

## 变更记录

本规范自身改动走同样的流程。修改规则时同步改 `docs/lint-commit-message.sh`，两者不一致视为缺陷。

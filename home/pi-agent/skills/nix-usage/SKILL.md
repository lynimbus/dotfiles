---
name: nix-usage
description: Nix 包管理器与 NixOS 专家（本机 Nix 2.34.8 / NixOS 26.11 unstable，技术细节本于 2.35.2 源码）。当涉及 nix 命令（build/run/shell/develop/eval/flake/profile/store/repl 等）、编写或调试 Nix 表达式与 flake.nix、nixpkgs/NixOS module/home-manager 配置、nixos-rebuild 与 nh 部署、store 维护清理、构建与求值错误排查时使用。
---

# Nix / NixOS 使用技能（源码级）

> 事实来源：NixOS/nix **2.35.2** 源码（`src/nix` CLI、`src/libexpr` 语言、`src/libstore` store、`src/libflake` flake）+ 本机实测。
> **本机实际是 Nix 2.34.8 / NixOS 26.11（nixos-unstable）**，配置仓 `~/dotfiles`（host `flakeos`）——见 §4。§0–§3 的机理与 CLI 已在 2.34.8 上校验，与 2.35.2 无实质差异（已知差异就地标注）。
> 实验特性：`nix build` 等新命令与 flakes 仍为实验特性，需 `experimental-features = nix-command flakes`（本机由 `nix.settings` 写入；`nix config show` 生效值还含 NixOS 隐式开启的 `fetch-tree`）。

---

## 0. 核心心智模型

### 0.1 一切皆 store path
- store path = `storeDir + "/" + <32位Nix32哈希>-<name>`。storeDir 默认 `/nix/store`，参与路径哈希计算。
- 路径哈希 = `sha256("<type>:<hash>:<storeDir>:<name>")` 截断到 160 bits，Nix32 编码（字母表 `0123456789abcdfghijklmnpqrsvwxyz`，排除 e o u t）。
- 名称校验：非空、长度 ≤ 211，字符集 `[0-9a-zA-Z]` 与 `+ - . _ ? =`；以 `.drv` 结尾表示 derivation。
- **两类寻址**：
  - **输入寻址**（普通 derivation）：输出路径是 derivation（.drv 内容）的函数 → "output path = f(drv)"。同一个 .drv 唯一决定输出路径，可复现。
  - **内容寻址**（CA）：输出路径是**内容**（NAR 哈希）的函数，与"谁构建的"无关 → 跨 derivation 去重/复用。前缀仅 `text` 与 `fixed`（`text:` 扁平文本如 .drv 本身/toFile 结果；`fixed:r:` NAR 目录、`fixed:git:`）。nixpkgs CI 用它缓存共享。
  - CA 输出路径构建前未知（2.35 名为 `DownstreamPlaceholder`，旧名 CAFloating），下游通过占位符引用（形式 `/<哈希>`，哈希由明文 `nix-upstream-output:<drvHashPart>:<outputName>` 计算），构建时重写；记录在 Realisation / `.doi` 文件。
- **NAR**（Nix ARchive）：规范化归档，保留可执行位/符号链接；narHash = NAR 序列化 sha256，**含文件权限**（内容同但权限异 → 哈希异）。

### 0.2 惰性求值
- 值是带判别位的联合（int/float/bool/null/string/path/attrs/list/function/thunk/failed）。
- 未求值的表达式是 **thunk**（环境 + 表达式）；被 force 时结果**写回原值单元**（记忆化，只算一次）。
- 求值前 thunk 先标记为**黑洞**（blackhole）；自引用（如 `rec { x = x; }`）再进入同一 thunk → `infinite recursion encountered`。
- `builtins.seq` 浅 force；`builtins.deepSeq` 递归 force。
- 失败的 thunk 缓存异常（`mkFailed`），再 force 重抛；`tryEval`/`Interrupted` 走 recovery 分支。

### 0.3 字符串上下文（NixStringContext）——依赖追踪的核心
字符串在求值器里携带**上下文**（一组 store path 引用），使 `"--with-foo=" + foo + "/lib"` 能正确把依赖记入 derivation。三种元素：
- `<path>`（Opaque）：普通 store path → 进 derivation 的 `inputSrcs`
- `=<drvPath>`（DrvDeep）：derivation 及**整个构建闭包**（含闭包内所有 drv 的所有输出）→ 全进 inputSrcs/inputDrvs
- `!<output>!<drvPath>`（Built）：某 drv 的某输出 → 进 `inputDrvs`

要点：
- 拼接/插值会**合并**上下文；`builtins.readFile` 会扫描文件内容中实际出现的 store 引用并附加 Opaque 上下文。
- 字符串相等比较**忽略**上下文。
- 需要无上下文字符串的场景（属性名、`substring` 起点等）强制报错："the string '...' is not allowed to refer to a store path"。
- `builtins.getContext` / `appendContext` 可读/写上下文；`unsafeDiscardStringContext` 丢弃（危险）；`unsafeDiscardOutputDependency` 把 DrvDeep 降级为 Opaque。
- 排查"为什么这个依赖被带上了"就用 `nix why-depends` + `--precise`。

### 0.4 闭包、GC 与替换
- **closure** = 路径 + references 传递闭包。references 在构建后对输出做 NAR 流扫描（匹配 32 位 hash part）记录到 SQLite（`Refs` 表）。
- **GC roots**：`<state>/gcroots`、`<state>/profiles`（generation symlink 即 root）、运行进程（/proc 扫描）、`<state>/temproots`。profile 每代是 `<profile>-<N>-link` 符号链接 + `addPermRoot`。
- **live/dead**：从所有 roots 沿 referrers 反向 BFS；碰不到 root 即 dead。`keep-derivations = true`（默认）让 derivation 连带其输出保留；`keep-outputs = false` 反之。
- **substituters**：默认 `https://cache.nixos.org/`，按 priority 升序；`.narinfo`（`<hashPart>.narinfo`）描述路径（StorePath/URL/NarHash/References/Sig/CA...），NAR 压缩文件 URL 为 `nar/<fileHash>.nar[.xz|.zst|...]`（fileHash 是**压缩后**哈希）。签名 fingerprint = `1;<path>;<narHash>;<narSize>;<refs>`，`require-sigs` 默认 true。
- **复制**：`copyPaths`/`copyClosure` 先拓扑排序，先传 references 再传路径本身；CA 路径在不同 storeDir 下按内容重算路径。

### 0.5 构建机制（少踩坑）
- 构建在 **sandbox**（Linux 默认开）：chroot，输入路径 bind-mount，`/build` 为构建目录，网络默认不通（fixed-output 除外）。
- builder 环境：`PATH=/path-not-set`（防污染）、`HOME=/homeless-shelter`、`NIX_BUILD_TOP`/`TMPDIR` 指向构建目录、`NIX_LOG_FD=2`。
- 构建后校验输出 → 规范化权限/时间戳 → 扫描 references → 算 narHash → 注册。
- `max-jobs`（默认 1；`auto`=CPU 数）、`cores`、`keep-going`、`fallback`（替换失败回退本地构建）、`--check`/`--rebuild`（重建对比，非确定性报错）。
- `post-build-hook` 环境变量：`DRV_PATH`、`OUT_PATHS`。

---

## 1. Nix 语言（libexpr 实现语义）

### 1.1 值类型
int（int64，溢出检测）、float（double）、bool、null、**string**（可带上下文）、**path**（"访问器 + 路径串"，不一定是本地文件）、attrset、list、lambda、primop、external、thunk。
`builtins.typeOf` 返回：`"int" "float" "bool" "string" "path" "null" "set" "list" "lambda"`（函数是 lambda！）。

### 1.2 语法速查（parser 验证）
```nix
# 字面量
42            # int
3.14          # float
"abc ${x}"    # 字符串插值（coerceMore=false：只收 string/path/带__toString或outPath的set！）
''缩进字符串
  ${x} 保留空行''      # ''-字符串：''' → ''，''\c 转义，自动剥最小缩进
./relative /abs ~/home <nixpkgs>   # 路径；<...> = __findFile __nixPath；~/ 纯模式下报错
./${pkg}/bin   # 路径插值（结果是 path 值）

# 属性集
{ a = 1; b = "x"; }          # 普通
rec { a = 1; b = a + 1; }    # 递归（自引用；注意 a = a 会无限递归）
{ inherit x y; }              # 从作用域继承
{ inherit (foo) a b; }        # 从 foo 取属性
{ "${dyn}" = v; }             # 动态属性名（let/inherit 中禁止）
a.b.c or default              # 带默认值的取属性（or 是关键字！）
e ? a.b                       # has-attr 运算符（不 force 值）

# let 是语法糖：let { ...; body = ...; } → (rec {...}).body
let x = 1; in x + 1

with pkgs; ...                # 作用域展开（查找是动态的：逐层 force attrset）
if c then a else b            # 只求值选中分支
assert x > 0; x               # 失败 → "assertion 'x > 0' failed"
f a b                         # 应用（柯里化）
x: x + 1                      # lambda
{ a, b ? 1, ... }: ...        # 模式参数 + 默认值 + 多余参数
args@{ a, ... }: ...          # @-pattern（整个参数集绑给 args）

# 运算符（脱糖到 builtins）
a < b  →  __lessThan a b       # <= > >= 同族
-x     →  __sub 0 x
a + b  # int/float 数值加；path+path 拼接；否则字符串拼接（路径插值时复制进 store）
a ++ b # 列表拼接（右结合）
a // b # 属性集合并（右操作数优先；右结合）
!a && b || c -> d              # 优先级: -> 最低，然后 || && == != < > // ! + - * / ++ ?
```

- 标识符允许 `'` 和 `-`（如 `foo'bar`、`x-y`）；`or` 既是关键字也可作属性名（`map or [...]` 触发弃用警告）。
- URL 字面量 `https://...` 现在按字符串解析并 lint 警告（建议加引号）。
- 重复属性是**解析期**错误："attribute 'x' already defined"；同名属性若两边都是 attrset 则合并（`{ a.b = 1; a.c = 2; }` 合法）。

### 1.3 求值语义要点
- **惰性**：属性值/列表元素/函数参数都是 thunk，用到才求值。
- **`with`**：查找失败时跳到外层 with 继续找；attrset 会动态 force。
- **函数调用**：缺必填参数 → "function 'x' called without required argument 'y'"；多余参数且无 `...` → "function 'x' called with unexpected argument 'y'"；缺 `?` 默认值用 `maybeThunk`（可引用其它 formals）。带 `__functor` 的 attrset 可被调用（functor）。
- **`//` 合并**：右优先；`a // b // c` 有延迟合并优化。
- **import 语义**：`import <path>` 相对路径基于**被导入文件所在目录**；`default.nix` 约定（目录 → 追加 /default.nix）；同一文件记忆化（只求值一次）；导入 `.drv` 文件得到 derivation 值；**IFD**（import-from-derivation）：import 一个需要构建的路径会触发构建（flake 纯模式下受限，`nix flake show` 会显示 "omitted due to use of import from derivation"）。
- **字符串强制转换**：`"${...}"` 不允许 int/bool/null（`"${1}"` 报错！）；`builtins.toString` 允许（bool→""/"1"，int/float→十进制，null→""，list→空格连接，attrset→__toString 或 outPath）。attrset 转字符串：先 `__toString`，否则 `outPath`（这就是 `"${drv}"` 得到 out 路径的原因）。

### 1.4 builtins 速查（重要：哪些**不在** builtins 里）
列表：`map`（惰性！）`filter`（急切）`foldl'`（**严格**左折叠，唯一内置 fold）`genList` `length` `elem` `elemAt` `concatLists` `concatMap` `head` `tail` `sort` `partition` `groupBy` `any` `all` `catAttrs`（**以上均 builtin**，2.34+ 把 nixpkgs lib 常用列表函数原生化）`reverseList`→**不是 builtin**（在 nixpkgs `lib.lists`）`take`/`drop`/`foldl`（**均非 builtin**，用 `lib`）。
属性集：`attrNames`（**字母序**）`attrValues`（同序）`getAttr` `hasAttr` `removeAttrs` `listToAttrs`（重名**第一个**优先）`mapAttrs`（惰性）`zipAttrsWith` `intersectAttrs`（值取自 e2！）`isAttrs` `functionArgs` `unsafeGetAttrPos`。`mapAttrsRecursive` 非 builtin（lib）。
字符串/路径：`toString` `toJSON` `fromJSON` `toXML` `readFile`（附带文件内实际 store 引用的上下文）`readDir` `pathExists` `baseNameOf` `dirOf` `match`（完整匹配 POSIX 扩展正则）`split` `replaceStrings` `concatStringsSep` `substring`（字节位置）`stringLength` `compareVersions` `splitVersion` `parseDrvName` `hashString` `hashFile` `convertHash` `storePath`（**纯模式禁用**）`toFile`（text 寻址）`filterSource` `path` `placeholder`。
数学：`add` `sub` `mul` `div`（int 溢出检测/除零报错；任一 float 则浮点）`bitAnd/Or/Xor` `lessThan` `ceil` `floor`。**`log`/`pow`/`sin`/`cos`/`tan`/`atan`/`mod` 不是 builtin**（lib 里有）。
控制流：`throw`（可被 tryEval 捕获，是 AssertionError 子类）`abort`（tryEval **不**捕获）`trace` `traceVerbose` `warn` `seq` `deepSeq` `tryEval`（只捕获 throw/assert，浅求值）`addErrorContext` `isNull/isFunction/isInt/isFloat/isString/isBool/isPath/isAttrs/isList` `genericClosure` `getEnv`（纯模式恒 ""）`currentTime`/`currentSystem`（纯模式禁用；currentTime 每次求值会话取一次）。
fetch：`fetchGit` `fetchTree` `fetchTarball` `fetchurl` `fetchMercurial` `getFlake` `parseFlakeRef` `flakeRefToString`。`fetchClosure` 需 `fetch-closure` 实验特性才注册；`fromTOML` 需 `Xp::FromTOML`。
derivation：`derivation`（Nix 包装）`derivationStrict`（C++ 核心）`outputOf`（动态 derivation，需 `dynamic-derivations` 实验特性才注册）。

### 1.5 derivation 机理
`derivationStrict` 流程：校验 `name`/`builder`/`system` 必填 → 其余属性 `coerceToString(coerceMore=true)` 成为环境变量（`args` 成 builder 命令行参数）→ 收集字符串上下文成 inputDrvs/inputSrcs → 算输出路径（fixed-output 有 outputHash；`__contentAddressed`/`__impure` 走 CA/占位符；普通输入寻址先算 masked 哈希）→ ATerm 序列化写 .drv → 结果 attrset 含 `drvPath`（DrvDeep 上下文）、各输出路径（Built 上下文）、`type = "derivation"`（derivation.nix 包装层加）。
- 产物结构：`{ outPath, drvPath, type = "derivation", outputName, outputs, all, drvAttrs }`。
- 输出选择默认 `out`；`outputs = [ "out" "dev" ]` 可多输出。
- `meta.outputsToInstall` 决定 `nix build` 默认装哪些输出（如 libxml2 → bin+man）。
- 两个 derivation 相等比较**只比 outPath**。
- `__structuredAttrs = true`：环境改为 JSON 文件（`.attrs.json`/`.attrs.sh`），更安全（nixpkgs 新打包推荐）。

### 1.6 常见错误与排查
| 错误 | 含义 | 修法 |
|---|---|---|
| `infinite recursion encountered` | 黑洞：自引用/循环 | 检查 rec/let 自引用、`with` 循环 |
| `attribute 'x' missing` | 取属性失败（带拼写建议） | 检查拼写、是否惰性未定义 |
| `cannot coerce an integer to a string` | `"${1}"` 插值数字 | 用 `builtins.toString 1` |
| `function 'x' called with unexpected argument 'y'` | 多传参且无 `...` | 加 `...` 或去掉参数 |
| `assertion '...' failed` | assert 失败（== 会给左右值诊断） | 看诊断 |
| `stack overflow; max-call-depth exceeded` | 递归过深（默认 10000） | 改尾递归/迭代 |
| `attribute 'x' already defined` | 解析期重复属性 | 合并或改名 |
| `the string '...' is not allowed to refer to a store path (such as '...')` | 属性名/索引带了上下文 | `unsafeDiscardStringContext` 或重构 |
| `cannot call 'getFlake' on unlocked flake reference` | 纯模式要求锁定引用 | `--impure` 或先 `nix flake lock` |

排查套路：`nix eval --json --show-trace` 看完整 trace 栈；`nix eval --apply` 后接函数；REPL（`nix repl`）里 `:p` 深打印、`:t` 看类型；错误时可 `--debugger` 进入交互调试（`:bt` 回溯、`:st` 看栈、`:c` 继续）。

---

## 2. Flake 体系（libflake）

### 2.1 flake.nix 顶层 schema
只允许 4 个顶层属性，其余报 "unsupported attribute"：
- `description`（string）
- `inputs`（attrset）：每个 input 可含 `url`、`flake`（bool，默认 true；false = 静态源码不进求值）、`follows`（如 `"nixpkgs"` 或 `"a/b"`，**与 ref/url 互斥**）、`inputs`（嵌套覆盖）、任意 fetcher 属性（`rev`/`ref`/`narHash`/`owner`/`repo`/`submodules`）。`inputs.self` 仅顶层可用（加 submodules/lfs）。
- `outputs`（**必须存在且是函数**）：形参除 `self` 外自动成为**隐式 input**（按名字走 registry）。
- `nixConfig`：临时配置（白名单外的设置需 `--accept-flake-config` 或已信任记录）。

### 2.2 outputs schema（`nix flake check` 的校验为准）
- `packages.<system>.<name>`、`devShells.<system>.<name>`、`checks.<system>.<name>`、`formatter.<system>` — derivation
- `apps.<system>.<name>` — 必须 `{ type = "app"; program = "..."; meta.description? }`
- `overlays.<name>` — lambda（必须接受 `final` 参数）；顶层 `overlay` 已弃用 → `overlays.default`
- `nixosModules.<name>`、`nixosConfigurations.<name>`、`hydraJobs`、`templates.<name>`（需 path+description）、`bundlers.<system>.<name>`
- `legacyPackages.<system>` — 社区约定，不检查内容
- **homeConfigurations / homeModules / flakeModules 等：已知但**不检查**（社区属性，非 Nix 内建 schema）**
- 弃用别名（会 warn）：`defaultPackage`→`packages.<system>.default`、`defaultApp`、`devShell`→`devShells.<system>.default`、`defaultTemplate`、`defaultBundler`、`nixosModule`→`nixosModules.default`

### 2.3 flakeref 语法
```
nixpkgs                    # flake ID → registry 解析（indirect ref）
nixpkgs/nixos-unstable     # flake ID + ref
github:NixOS/nixpkgs/nixos-unstable   # URL 形式（owner/repo[/rev][?ref=...][?dir=...]）
git+https://github.com/foo/bar?ref=main&dir=subdir
path:./relative  .#       # 裸路径（无 scheme 视为路径）：向上找含 flake.nix 的目录；
                          #   遇到 .git 转 git+file://（带 dir=subdir）；跨文件系统边界报错
# 统一语法: <flake-ref>#<attrpath>^<outputs>
nixpkgs#hello              # registry 查 nixpkgs → 取 packages.x86_64-linux.hello（默认前缀）
.#myPkg                    # 当前 flake
path:/tmp/repo#checks.foo
```
- 默认属性路径：无 `#` 时试 `packages.<system>.default`、`defaultPackage.<system>`；有 `#attr` 时按 `packages.<system>.`、`legacyPackages.<system>.` 前缀搜索；`#.attr`（点开头）精确查找跳过前缀。
- `^out,dev` 选择输出；`^*` 全部。

### 2.4 flake.lock（version 7）
```json
{ "version": 7, "root": "nixpkgs", "nodes": {
  "nixpkgs": { "locked": { "type": "github", "owner": "NixOS", "repo": "nixpkgs", "rev": "...", "narHash": "...", "lastModified": 123 },
               "original": { "type": "indirect", "id": "nixpkgs" } },
  "home-manager": { "locked": {...}, "original": {...}, "inputs": { "nixpkgs": ["nixpkgs"] } } } }
```
- `locked` = 锁定后的 fetcher 属性；`original` = flake.nix 里写的（用于判断过期）；`inputs` 里 `["nixpkgs"]` 表示 follows。
- 锁匹配：`originalRef.canonicalize() == input.ref` 且 parent 一致 → **复用旧锁不 fetch**。
- `nix flake update [inputs...]` 强制重取；`nix flake lock` 只补缺失；`--override-input <path> <ref>` 覆盖（**sticky**，写进 original；隐含 --no-write-lock-file 需配合）。
- 纯模式下：新 input 必须可锁定；`warn-dirty` 为 true 时未提交改动只 warn。

### 2.5 registry
- 用户 registry：`~/.config/nix/registry.json`（`nix registry add/list/remove/pin/resolve`）。
- 系统 registry：`flake-registry` 配置（内置 flake-registry）。
- 纯模式下 registry **禁用**（源码 `!pureEval && use-registries`，`use-registries` 默认 true）——所以 `nix flake show nixpkgs` 类命令要带 `--impure` 或用完整 URL。

### 2.6 纯求值（pure eval）
flake 命令默认 `pureEval = true`：禁用 `builtins.currentTime`/`currentSystem`/`nixPath`/`storePath`，registry 禁用，flake 源码只读挂载，getFlake 拒绝未锁定引用。需要不纯时加 `--impure`（`nix develop`/`nix repl` 默认 impure）。

---

## 3. CLI 速查（本机 2.34.8 已校验）

### 3.1 全局选项（任何命令可用）
```
--impure / --pure-eval           # 求值纯度开关
-v/-vv/--quiet/--debug           # 详细度
-L/--print-build-logs            # 打印构建日志（默认进度条）
--show-trace                     # 出错显示完整求值 trace
--debugger                       # 求值失败进交互调试器
-j/--max-jobs N  --cores N       # 并行度
--keep-going  --keep-failed    # 失败继续 / 保留失败输出（<path>.check 或 scratch）【隐藏：--help 不列但可用】
--fallback                       # 替换失败回退构建【隐藏】
--offline / --no-net             # 禁用网络（substituters 关闭）【--no-net 隐藏】
--refresh                        # 所有已下载视为过期
--option <name> <value>          # 覆盖 nix.conf 配置
--store <store-uri>              # 指定 store（local?root=/tmp/nix、daemon、ssh-ng://host、s3://b）
--eval-store <url>               # 分离求值 store
--extra-experimental-features <list>
--arg <name> <expr> --argstr     # 传参给顶层函数（与 flake 不兼容）
-I/--include <path>              # 查找路径（nix-path）
```
- **本机 nix.conf（NixOS，由 `nix.settings` 生成 `/etc/nix/nix.conf`）**：`experimental-features = nix-command flakes`（但**生效值含 `fetch-tree`**）、`auto-optimise-store = true`、`warn-dirty = false`、`max-jobs = auto`（实测 16）、`cores = 0`、`sandbox = true`、`require-sigs = true`、`trusted-users = root`。
  - `build-users-group` **不在 `/etc/nix/nix.conf` 里**，普通用户 `nix config show build-users-group` 看到的是空——那是客户端本地解析视角，不代表 daemon 端值（系统确实有 `nixbld` 组，gid 30000，nixbld1–32）。凡是只有 daemon 才用的项，都不要拿普通用户的 `config show` 当证据。
  - `nix config show` = nix.conf + 编译默认 + 客户端覆盖；非 trusted user 的受限设置（`substituters`、`trusted-public-keys`）会被忽略并告警。
- `#!nix` shebang 脚本支持（`#!nix develop -c ...`）。

### 3.2 installable 语法
`[flake-ref]#[attrpath][^outputs]`，如 `nixpkgs#hello`、`.#devShell`、`/nix/store/xxx.drv^out`、`./result`（符号链接链）。`--file/-f` 或 `--expr/-E` 模式与 flake 互斥（`--arg` 只配 -f/-E）。

### 3.3 命令分组
**构建/运行**：
- `nix build [installable]`：求值+构建；建 `./result` 符号链接（第 N 个 `result-N`，多输出 `result-<out>`；`-o/--out-link`、`--no-link`）；`--print-out-paths` 打印路径；`--json` 含 drvPath/outputs/耗时；`--dry-run`；`--rebuild`（--check 语义）；`--profile` 装进 profile（要求恰好一个输出路径）。默认输出按 `meta.outputsToInstall`，否则 `out`。
- `nix run`：默认 `apps.<system>.default` → `type="app"` 取 `program`；否则 derivation → `meta.mainProgram ?: pname ?: name`，跑 `<out>/bin/<mainProgram>`（execve 绝对路径，不走 PATH）。`--ignore-env/-i`、`--keep-env-var/-k <name>`、`--set-env-var/-s <name> <val>`、`--unset-env-var/-u <name>` 控制环境变量（**短选项在 2.34.8 仍可用**，“已移除”的说法不成立）。
- `nix env shell`（主命令，`nix shell` 是别名）：只把各输出 `bin/` 加入 PATH（递归处理 `nix-support/propagated-user-env-packages`），执行 `$SHELL`（默认 bash）或 `-c <cmd>`。**没有 `-p`**（那是 legacy nix-shell）。
- `nix develop`：完整重建 stdenv 构建环境（变量/函数/shellHook/phase）——把 builder 换成 get-env.sh 重新生成 env 输出再 source；`-c/--command`、`--phase/--unpack/--configure/--build/--check/--install`、`--redirect`、`--profile`；交互式 `bash --rcfile`。**`nix develop` 要求 builder 是 bash**。`nix print-dev-env`（同族）输出可 source 的 env（`--json`）。
- 区别记忆：`nix shell` = 加 PATH；`nix develop` = 完整 stdenv 环境 + shellHook + phase。

**profile**：
- `nix profile add/remove/upgrade/list/diff-closures/history/rollback/wipe-history`（`install` 是 add 的弃用别名；数字索引已不支持 → 用名字/`--regex`/`--all`）。
- profile = store 内 symlink tree + manifest.json（version 3）；generation = `<profile>-<N>-link` + addPermRoot（GC root）。冲突文件会提示 `--priority`（默认 5）。
- **本机（NixOS）不用 `nix profile`**：软件全由 `~/dotfiles` 声明，系统代在 `/nix/var/nix/profiles/system-<N>-link`。`nix profile` 仅临时实验用，别拿它装长期软件（会跟声明式配置逆向漂移）。

**store**：
- `nix store add/ls/cat`（`--mode nar|flat|text`）、`nix store gc`（`--max`）、`nix store delete`（`--ignore-liveness`）、`nix store optimise`（硬链接去重）、`nix store verify`（退出码 1=损坏 2=未信任 4=失败）、`nix store repair`、`nix store info`（ping）、`nix store prefetch-file`、`nix store make-content-addressed`（闭包转 CA，`--json` 给重写映射）、`nix store copy-log`、`nix store sign/copy-sigs`、`nix store diff-closures`、`nix store dump-path`、`nix store path-from-hash-part`。
- `nix nar ls/cat/pack`、`nix path-info`（`-s` 大小 `-S` 闭包大小）、`nix hash` 三子命令：`hash path`（`--mode nar|flat|git`、`--format sri|base16|base32|base64`）、`hash file`（`--base16/32/64`、`--sri`、`--type`）、`hash convert`（`--to`、`--hash-algo`）。
- `nix copy --from/--to`（默认整闭包递归）、`nix log`（构建日志，pager）、`nix why-depends <pkg> <dep>`（`-a` 所有边、`--precise` 文件级引用）、`nix diff-closures <a> <b>`（**已弃用**，主命令 `nix store diff-closures`）。

**flake**：
- `nix flake show`（输出树）、`nix flake update [inputs]`、`nix flake lock`、`nix flake check`（`--no-build` 只求值、`--all-systems`）、`nix flake metadata`（`info` 弃用）、`nix flake archive`（整个 flake+inputs 进 store/`--to`）、`nix flake prefetch`、`nix flake init/new`（`-t` 模板）、`nix flake clone`、`nix flake prefetch-inputs`。

**求值/调试**：
- `nix eval [installable]`：`--json`（strict）、`--raw`（字符串不打引号）、`--apply <expr>`、`--write-to <dir>`、`--read-only`（不实例化 derivation，性能）。`nix eval nixpkgs#legacyPackages.x86_64-linux.hello.name` 这种探路法很常用。
- `nix repl`：稳定命令、默认 impure；`:t` 类型、`:p` 深打印、`:a` 把 attrset 加进作用域、`:e` 编辑器打开定义、`:b` 构建、`:doc` builtin 文档、`:sh` 进 shell、`:lf <ref>` 加载 flake、`:q` 退出。多行表达式自动续行。
- `nix search nixpkgs <regex>`（`-e` 排除）、`nix edit`、`nix config show/check`、`nix derivation show [-r]`（`-r` 含闭包）、`nix derivation add`、`nix registry *`、`nix fmt`（formatter）。

**其他**：
- `nix key generate-secret` / `convert-secret-to-public`：自建二进制缓存的签名密钥（配 `nix store sign`）。
- `nix realisation info`：查 CA derivation 的 realisation 映射（对应 §0.1 的 `.doi`）。
- `nix help-stores`（store 类型与可用设置，查 `--store` 写法时有用）、`nix daemon`（root）、`nix bundle`（打包单文件）、`nix formatter run/build`。
- `nix upgrade-nix` 在 NixOS 上**不要用**：nix 版本由系统配置的 `nix.package` 控制。

**传统命令**（argv[0] 分发，映射到新命令）：
`nix-build`→`nix build`（但 nix-build 默认解析 default.nix）；`nix-shell -p/--run`→`nix develop/shell`（`-p` 构造 runCommand 壳）；`nix-env`→`nix profile`；`nix-instantiate`→`nix eval`/`nix derivation show`；`nix-channel`→registry/flake；`nix-collect-garbage -d`→`nix store gc`+profile wipe-history；`nix-copy-closure`→`nix copy`；`nix-store --gc/--query`→`nix store *`；`nix-prefetch-url`→`nix store prefetch-file`。

---

## 4. 本机工作流（~/dotfiles，NixOS）

### 4.1 事实基线
- **NixOS 26.11**（`nixos-version` → `26.11.20260822.2c423e0` Zokor），nixpkgs 跟 **nixos-unstable**；`stateVersion = "26.05"` 只是兼容基线，**不代表通道**。
- 配置仓 `~/dotfiles`，host = `flakeos`，用户 `lynimbus`，`x86_64-linux`。
- **home-manager 是 NixOS module**（`home-manager.nixosModules.home-manager` + `home-manager.users.<u>`），**没有 standalone `homeConfigurations`** → **不存在 `home-manager switch`**，用户层改动同样走 `nixos-rebuild`。从 Arch 时代 standalone home-manager 迁过来最容易搞错这一点。
- 部署包装器 `nh` 4.4.x，命令入口 `justfile`，闭包对比 `nvd`，`nix fmt` → nixfmt 1.4.0。
- `~/dotfiles` 用 **jj colocate** 管理（`.jj` + `.git` 并存）。

### 4.2 结构
```
~/dotfiles/
├── flake.nix        # inputs: nixpkgs(nixos-unstable) + home-manager(follows) + nixos-hardware + deepseek-harness + niri/zed/zig overlays
│                    # outputs: nixosConfigurations.flakeos、formatter=nixfmt
│                    # 顶层 let 定义 system/username/email，经 specialArgs 与 extraSpecialArgs 下传
├── flake.lock
├── justfile         # switch/build/boot/update/check/diff/rollback/gc
├── AGENTS.md        # 仓库硬约定
├── hosts/flakeos/
│   ├── configuration.nix          # 系统层：引导/内核/Plasma6+SDDM/fcitx5-rime/PipeWire/locale/nix.settings/nix.gc/programs.nh
│   └── hardware-configuration.nix # nixos-generate-config 生成，勿手改
├── home/flakeos.nix               # 用户层：home.packages + programs.*
└── pkgs/zed-prebuilt.nix          # 官方 release 预编译 zed
```

### 4.3 决策矩阵
| 场景 | 做法 |
|---|---|
| 内核、引导、系统服务、桌面/登录管理器、输入法、字体、locale、nix 设置 | `hosts/flakeos/configuration.nix` |
| 用户级软件与程序配置（有 `programs.<name>` module 就用 module） | `home/flakeos.nix` |
| flake input、用户名邮箱、overlay | `flake.nix` |
| 临时用一次 | `nix shell nixpkgs#<pkg>` / `nix run nixpkgs#<pkg>` |
| nixpkgs 没有该包 | 自建包放 `pkgs/`，在 `flake.nix` overlay 里 `final.callPackage` 注入 |
| 上游只发 AppImage / 预编译二进制 | `pkgs.appimageTools.wrapType2` 或 `buildFHSEnv`；跑闭源二进制用 `steam-run` |
| nixpkgs 版本滞后 | 覆盖 `src`/`version` 的 overlay，或临时 `nix run github:owner/repo` |

判据：**登录前就要存在的东西**（内核、显示管理器、系统服务、全局 PATH）进系统层；**只服务当前用户的东西**进 home 层。拿不准优先 home——回滚粒度更细，不必重建整个系统闭包。

### 4.4 日常命令（justfile）
```bash
just switch      # nh os switch .        部署（nh 内部自行提权，无需手写 sudo）
just build       # nh os build .         只构建校验
just boot        # nh os boot .          写引导项，下次开机生效（内核/驱动变更）
just update      # nix flake update && nh os switch .
just check       # nix flake check --no-build   秒级求值校验，改完先跑这个
just diff        # nh os build . --diff always  （nh 内置 nvd 包版本差异）
just diff-gen a b # nvd diff 任意两代系统 profile
just rollback    # sudo nixos-rebuild switch --rollback --flake .#flakeos
just generations # nixos-rebuild list-generations（无需 sudo）
just fmt         # nix fmt
just gc          # sudo nix-collect-garbage -d --delete-older-than 14d && nix store optimise
```
裸命令等价物：`sudo nixos-rebuild switch --flake .#flakeos`。

### 4.5 注意事项
- **`nix flake update` 绝不加 sudo**：会把 `flake.lock` 属主改成 root，之后普通用户改不动（本机踩过）。修复：`sudo chown lynimbus:users flake.lock`。
- **托管文件是 /nix/store 符号链接**：改配置一律改 flake 源文件 → `just switch`，**勿手改 ~/.config**；home-manager 遇到已存在的真实文件按 `backupFileExtension = "bak"` 改名让路，别把 `.bak` 当配置改。
- **二进制缓存要写进 `configuration.nix` 的 `nix.settings`**，不能只写 `flake.nix` 的 `nixConfig`——后者只对 `trusted-users` 生效，而本机 `trusted-users` 只有 root，普通用户跑 `nix build` 会看到 "ignoring untrusted substituter"。临时救急 `--accept-flake-config`（仍受 trusted-users 限制）。
- **`nix.gc` 与 `programs.nh.clean` 只能开一个**（都是定时清理，NixOS module 有 assertion）。本机用 `nix.gc`（weekly、`--delete-older-than 14d`）。
- **unstable 上 home-manager 选项改名频繁**（实测 `programs.git.userName/userEmail/extraConfig` → `programs.git.settings.{user.name,user.email,…}`）。`just check` 打出的 `evaluation warning: ... has been renamed to ...` 是下次升级会变硬错误的地方，**别忽略**。
- 装包前确认 `nix eval nixpkgs#<pkg>.version`；包名偶有出入（`delta`、`yq-go`）。
- 部署后验证 `command -v <pkg>` 应指向 `/nix/store`（用户层经 `/etc/profiles/per-user/<u>/bin` 转一跳）。
- 本机有 specialisation `battery-saver`（来自 nixos-hardware 的 mechrevo-gm5hg0a profile），`nixos-rebuild list-generations` 会显示；临时切换用 `/run/current-system/specialisation/battery-saver/bin/switch-to-configuration test`。

### 4.6 NixOS module 系统（从 standalone home-manager 迁过来必读）

#### 求值结构
`lib.nixosSystem { modules = [ ... ]; specialArgs = {...}; }` 把所有 module 合并求不动点：
- **module 形式**：`{ config, lib, pkgs, ... }: { imports = [...]; options = {...}; config = {...}; }`；没写 `options`/`config` 时整个 attrset 当 `config`（本仓的 configuration.nix 就是这种）。
- **`config` 是最终合并结果**（不是当前文件写的），可读其他 module 的值 → module 之间天然互相可见，也因此容易无意制造 infinite recursion（`config.x` 又去定义 `x` 的前提）。
- **`specialArgs` vs `_module.args`**：`specialArgs` 在 module 求值**之前**注入，可在 `imports` 里用；`_module.args` 是求值结果，不能用于 `imports`。本仓用 `specialArgs = { inherit inputs username; }` 传系统层，`extraSpecialArgs = { inherit inputs username email; }` 传 home 层（home-manager 单独一套，**两边不共享**）。
- **选项合并**：list 默认拼接（`environment.systemPackages` 各 module 叠加）；attrset 递归合并；标量多处定义不同值则**报错**，需 `lib.mkForce`（覆盖）/`lib.mkDefault`（让位，优先级 1000）/`lib.mkOverride <n>`。`lib.mkIf cond {...}` 条件启用整块配置。
- 查选项实际生效值：`nix eval .#nixosConfigurations.flakeos.config.<路径>`；看选项定义与默认：`nix eval .#nixosConfigurations.flakeos.options.<路径>.{description,default,type.description}`。这两条比翻文档快，且不会因上游改名而过时。

#### nixos-rebuild 做了什么
1. 求值 `nixosConfigurations.<host>.config.system.build.toplevel` → 构建出一个 store path（整个系统闭包）。
2. `switch`：把该路径注册为 `/nix/var/nix/profiles/system` 新一代（GC root）→ 跑 `<toplevel>/bin/switch-to-configuration switch` → 写 bootloader 条目 + 重启/重载变动的 systemd unit。
3. 子命令语义：`switch`（立即生效 + 写引导）、`boot`（只写引导，下次开机）、`test`（只生效，**不写引导**，重启即消，试验危险改动用它）、`build`（只构建出 `./result`）、`dry-activate`（构建 + 打印将执行的激活动作，不真改）。
4. **回滚本质是指向旧 profile 代**：`--rollback` 或 GRUB/systemd-boot 菜单选旧代。只要旧代没被 GC，**就一定能回去**——这是 NixOS 比 Arch 最大的安全网；反之，`nix-collect-garbage -d` 会删旧代，**删完就回不去了**，升级后先跑一阵再 gc。
5. `nh os switch` = 上述流程的包装（进度漂亮、自行提权、内置 nvd diff），不改变语义。

#### specialisation
`specialisation.<name>.configuration = {...}` 会额外构建一份变体闭包，放在 `/run/current-system/specialisation/<name>/`，引导菜单也会多一项。临时切：`sudo /run/current-system/specialisation/<name>/bin/switch-to-configuration test`。本机的 `battery-saver` 来自 nixos-hardware 的 mechrevo profile（`nixos-rebuild list-generations` 的 Specialisation 列可见）。

#### 排查 NixOS 特有的坑
- **选项名拼错 → “The option `xxx' does not exist”**：直接 `nix eval .#nixosConfigurations.flakeos.options.<父路径>` 列 attrNames 看真实选项名。
- **`has been renamed to` / `is deprecated` 警告**：unstable 上很常见，下个 release 就会变硬错误，看到就改。
- **assertion failed**：module 的 `assertions` 机制，报文就是原因（典型：`nix.gc` 与 `programs.nh.clean` 同时开启）。
- **改了配置但服务没变**：`systemctl status <unit>` 看它指向的 store path，对比 `/run/current-system`；部分 unit 需手动 restart（switch-to-configuration 只重启它认为变了的）。
- **求值很慢**：整个系统闭包求值本来就重；只改 home 层也得重新求值全部，这是 NixOS module 方式集成 home-manager 的固有成本。

---

## 5. 排查与运维

### 5.1 常见任务
```bash
# 查包是否存在/版本
nix eval nixpkgs#<pkg>.version
# 试运行不装
nix run nixpkgs#<pkg>
# 查依赖链
nix why-depends nixpkgs#<pkg> nixpkgs#<dep>
# 对比两代系统的包版本差异（NixOS 用系统 profile，不是用户 profile）
nvd diff /nix/var/nix/profiles/system-{22,23}-link
nix store diff-closures /nix/var/nix/profiles/system-{22,23}-link
# 部署历史
nixos-rebuild list-generations
# 看 store 用量
nix path-info -Sh /nix/store/* | sort -k2 -h | tail
# 清理
sudo nix-collect-garbage -d --delete-older-than 14d
nix store optimise
# 导出/导入闭包（换机）
nix copy --to ssh-ng://host /nix/store/xxx
```

### 5.2 错误定位流程
1. 报错信息 → 对照 §1.6 错误表。
2. 加 `--show-trace` 看求值栈（"while evaluating the attribute '...'" 链）。
3. `nix eval --json nixpkgs#<attr>` 逐段定位是哪个属性炸。
4. 复杂表达式进 `nix repl` 分步 `:t`/`:p`。
5. 构建失败：`-L` 看完整日志；`--keep-failed` 保留现场（`<path>.check` / scratch dir）；查构建环境 `nix develop -c env`。
6. 依赖莫名带进来：`nix why-depends --precise <pkg> <dep>` 看具体引用文件（字符串上下文泄漏常见于 `builtins.toString`/路径拼接）。

### 5.3 性能提示
- 求值慢：`nix eval` 带 `--read-only` 跳过 derivation 实例化；`nix flake show` 用 eval cache（fingerprint 缓存跨进程）。
- 构建慢：`-j auto`（`max-jobs = auto` 默认 CPU 数）、`--cores`；替换慢调 `max-substitution-jobs`（默认 16）。
- store 膨胀：`auto-optimise-store`（本机已开）自动硬链接去重；`nix.gc` weekly 自动清 14 天前的代。
- `warn-dirty = false`（本机 `nix.settings` 已设）：jj 管理下工作副本常脏，避免每次 flake 操作警告。

---

## 6. 常见坑速查（源码级教训）

1. **`"${int}"` 报错**：插值不强制数字，`builtins.toString` 才行（coerceMore 差异）。
2. **`builtins.attrNames` 是字母序**，不是书写序；依赖顺序时先 `lib.sort` 或显式排序。
3. **`builtins.listToAttrs` 重名第一个优先**；`//` 是右侧优先——别混用。
4. **`builtins.take/drop/foldl/reverseList/mapAttrsRecursive/log/pow/sin` 等不是 builtin**，用 `pkgs.lib`。
5. **`tryEval` 只捕获 throw/assert**，不捕获 abort/类型错误；且是浅求值（`tryEval {x = throw "";}` → success=true）。
6. **`rec` 自引用黑洞**：`rec { x = x; }` → infinite recursion；间接自引用（a→b→a）同样。
7. **with 是运行时查找**：`with a; with b;` 遮蔽语义 + 每次 force；滥用拖慢求值。
8. **字符串上下文**：给字符串拼接路径/derivation 会带依赖进 inputDrvs——通常是你想要的；想去掉用 `unsafeDiscardStringContext`（会破坏依赖，慎用）。
9. **flake 纯模式**：`nix flake show nixpkgs` 之类需要 registry 的命令要 `--impure` 或给完整 URL。
10. **`nix develop` 需要 bash builder**；`nix shell` 才轻量（只 PATH）。
11. **nix build 默认输出**看 `meta.outputsToInstall`（不是只有 out）；多输出记得 `^out,dev` 或 `result-dev`。
12. **`--override-input` 是 sticky 的**，会写进锁；用完注意还原或更新锁。
13. **路径插值复制进 store**：`"${./file}"` 把文件复制到 /nix/store（带上下文），不要用于应保持相对路径的场景（用 `builtins.path` 或直接路径）。
14. **URL 字面量被 lint**：`https://...` 裸写会警告/报错（`lint-url-literals`），加引号。
15. **`nix shell` 没有 `-p`**；legacy `nix-shell -p` 语法不通用。
16. **derivation 相等只比 outPath**；`assert a == b` 会输出两侧诊断。
17. **eval 溢出/除零**：int64 溢出和除零都是求值错误。
18. **home-manager 托管文件是符号链接**：改配置走 flake，别直接编辑 ~/.config。
19. **home-manager 作为 NixOS module 时没有 `home-manager` 命令**：用户层改动也要 `nixos-rebuild`/`nh os switch`，别去找 `home-manager switch`。
20. **`flake.nix` 的 `nixConfig` 对非 trusted user 无效**：substituter/公钥要落到系统 `nix.settings`，否则只会看到 "ignoring untrusted substituter" 然后全部本地编译。

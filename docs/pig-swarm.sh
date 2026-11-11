#!/usr/bin/env bash
# Fan N pig agents out over one problem, with a bd epic as the ledger.
#
# The problem becomes an epic, each worker owns one child issue, and every worker
# publishes what it did as a comment on that child before closing it. Nothing is
# passed between workers at run time: an issue is the unit of work, '`bd update
# --claim`' is the lock, a comment is the deliverable, and closed is the done
# signal. A worker that died can therefore be re-run alone against the same epic
# instead of redoing the ones that finished.
#
#   pig-swarm "fix the flaky checkout test"
#   pig-swarm "migrate the remaining callers" "cli" "server" "docs" "tests"
#   pig-swarm -m "a/model,b/model,c/model" "why does the cache go stale"
#   pig-swarm -w "cut login over to the new API" "routes" "session" "tests"
#   pig-swarm -D "anything"           # print the plan, create nothing
#
# One positional is the problem; every further positional is one worker's part of
# it. Without parts every worker is told to finish the whole problem itself, which
# is what makes -m "a,b,c" a model race: same problem, different model, so a
# difference in the answers is the difference in the models.
#
# Writing: a worker that may edit files needs a tree of its own, or two agents race
# over the same file. -w gives each of them a git worktree on its own branch, and
# the report lists the branches to review and merge. Without -w the workers are
# read-only: they answer, and a change they want goes into their comment as a patch
# or as steps.
#
# Where you see them: inside Kero each worker is a pane running the real pig TUI,
# started with its brief as the first message, so it looks exactly like a session
# of your own and stays one afterwards. The panes are laid out as a grid rather
# than a stack -- as many columns as a square needs -- so four workers are a 田. Anywhere else, or with PIG_SWARM_HIDDEN=1,
# there is no screen, so pig's JSON event stream is piped through a renderer into
# logs/wN.log: prose as it streams, one line per tool call, the head of each result.
#
# Environment, instead of more flags: PIG_SWARM_OUT (where logs and worktrees go),
# PIG_SWARM_HIDDEN=1 (logs even inside Kero), PIG_SWARM_APPROVE=1 (pass --approve,
# to let the workers read an untrusted project's AGENTS.md).

set -uo pipefail

# Inlined rather than sourced from docs/lib.sh: this file is also installed as a
# standalone program by pkgs/pig-swarm.nix, where no sibling script is on disk.
die() {
	printf '%s: %s\n' "${0##*/}" "$*" >&2
	exit 1
}

# A literal backtick in a printf format reads to shellcheck as command
# substitution inside quotes (SC2016), so code spans in this file are written as
# \x60, which bash printf turns into a backtick.

usage() {
	cat <<'USAGE'
usage: pig-swarm [options] PROBLEM [PART…]

  PROBLEM  what the swarm has to get done
  PART…    one worker's share of it, after the problem. With no PART every worker
           is told to finish the whole problem itself (a race when the models
           differ).

  -n N     workers (default: as many as there are PARTs, else 3)
  -d DIR   repository to work in (default: the current directory; needs .beads)
  -m M     pig --model; a comma list deals one model per worker
  -w       let the workers write: one git worktree and branch each
  -D       dry run: print the plan and create nothing
  -h       this text

env: PIG_SWARM_OUT (logs, prompts, worktrees), PIG_SWARM_HIDDEN=1 (logs instead
of Kero panes), PIG_SWARM_APPROVE=1 (trust project-local files for the run)
USAGE
	exit "${1:-0}"
}

workers=
repo=$PWD
models=
isolate=0
dry_run=0

while getopts ':n:d:m:wDh' opt; do
	case $opt in
	n) workers=$OPTARG ;;
	d) repo=$OPTARG ;;
	m) models=$OPTARG ;;
	w) isolate=1 ;;
	D) dry_run=1 ;;
	h) usage ;;
	*) die "unknown flag -$OPTARG (try -h)" ;;
	esac
done
shift $((OPTIND - 1))

[ "$#" -ge 1 ] || usage 1
problem=$1
shift
parts=("$@")

if [ -n "$workers" ]; then
	[[ $workers =~ ^[1-9][0-9]*$ ]] || die "-n wants a positive integer, got '$workers'"
elif [ "${#parts[@]}" -gt 0 ]; then
	workers=${#parts[@]}
else
	workers=3
fi
if [ "${#parts[@]}" -gt 0 ] && [ "$workers" -ne "${#parts[@]}" ]; then
	die "$workers workers but ${#parts[@]} parts: drop -n, or give one part per worker"
fi

# -m is a list, not a single model: worker i takes element i (mod length).
model_list=()
if [ -n "$models" ]; then
	IFS=',' read -r -a model_list <<<"$models"
fi
model_for() {
	local n=${#model_list[@]}
	[ "$n" -gt 0 ] || return 0
	printf '%s' "${model_list[$((($1 - 1) % n))]}"
}

cd "$repo" || die "no such directory: $repo"
repo=$PWD
[ -d .beads ] || die "$repo has no .beads (run 'bd init' there first)"
command -v pig >/dev/null || die "pig is not on PATH"
command -v bd >/dev/null || die "bd is not on PATH"
command -v jq >/dev/null || die "jq is not on PATH"
if [ "$isolate" = 1 ]; then
	git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 ||
		die "-w needs a git repository; $repo is not one"
fi

# Where the workers are seen: panes inside Kero, logs anywhere else.
if [ -n "${PIG_SWARM_HIDDEN:-}" ]; then
	display=logs
elif [ -n "${KERO_PANE:-}" ] && command -v kero >/dev/null; then
	display=panes
else
	display=logs
fi

# A trusted project lets the workers read its AGENTS.md and skills; anything else
# is ignored by a hidden run and refused by a pane, where the prompt would hang.
approve_flag=
[ -n "${PIG_SWARM_APPROVE:-}" ] && approve_flag=--approve
if [ "$display" = panes ] && [ -z "$approve_flag" ]; then
	trust=$(pig status --json 2>/dev/null | jq -r '.trust.state // "unknown"')
	if [ "$trust" != trusted ]; then
		if [ "$dry_run" = 0 ]; then
			die "$repo is not a trusted project, so a pane would stop at pig's trust prompt (set PIG_SWARM_APPROVE=1 to trust it for the run)"
		fi
		printf 'note: %s is untrusted, so a pane would stop at pig trust (PIG_SWARM_APPROVE=1 to allow)\n' \
			"$repo" >&2
	fi
fi

# A run has to be findable from the problem alone, or a second run of the same
# problem opens a second epic and the work never meets. The readable part comes
# from the problem's ASCII words; a problem with none, or with non-ASCII in it,
# also carries a hash, so two Chinese problems sharing a stray English word cannot
# land on the same epic.
slug=$(printf '%s' "$problem" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' |
	cut -c1-32 | sed 's/^-*//; s/-*$//')
if [ -z "$slug" ] || printf '%s' "$problem" | LC_ALL=C grep -q '[^ -~]'; then
	slug="${slug:-swarm}-$(printf '%s' "$problem" | sha256sum | cut -c1-8)"
fi
stamp=$(date +%Y%m%d-%H%M%S)
out=${PIG_SWARM_OUT:-${XDG_CACHE_HOME:-$HOME/.cache}/pig-swarm/$slug-$stamp}
mkdir -p "$out/sessions" "$out/logs"

# The renderer behind a hidden run: without a screen, pig's JSON event stream is the
# only thing that can show progress.
cat >"$out/render.jq" <<'RENDER'
def briefshrink(n):
  tostring | gsub("[ \t\r\n]+"; " ") | if length > n then .[0:n] + "…" else . end;

def argbrief:
  (.args // {}) as $a
  | ([$a.cmd, $a.path, $a.pattern, $a.url, $a.query, $a.code]
     | map(select(type == "string" and . != "")) | first) // ($a | briefshrink(90));

def resulthead:
  ([.result.content[]?.text // empty] | join(" "))
  | gsub("[ \t\r\n]+"; " ")
  | if length == 0 then "(no output)"
    elif length > 160 then .[0:160] + "…" else . end;

foreach inputs as $e (
  {streamed: false};
  if $e.type == "message_start" then .streamed = false
  elif ($e.type == "message_update" and ($e.assistantMessageEvent.type? // "") == "text_delta")
  then .streamed = true
  else . end;

  if $e.type == "message_update" then
    (if ($e.assistantMessageEvent.type? // "") == "text_delta"
     then $e.assistantMessageEvent.delta else "" end)
  elif $e.type == "tool_execution_start" then
    "\n\n→ " + ($e.toolName // "tool") + "  " + ($e | argbrief) + "\n"
  elif $e.type == "tool_execution_end" then
    (if ($e.isError // false) then "  ✗ " else "  │ " end) + ($e | resulthead) + "\n"
  elif $e.type == "message_end" and ($e.message.role? // "") == "assistant" then
    (if .streamed then ""
     else ([$e.message.content[]? | select(.type == "text") | .text] | join("\n")) + "\n\n"
     end)
  elif $e.type == "agent_settled" then "\n"
  else "" end
)
RENDER

# Reuse an open epic for the same problem: re-running it to pick up a worker that
# failed must not fork the ledger.
epic=$(bd list --label "swarm:$slug" --all --flat --json 2>/dev/null |
	jq -r '[.[] | select(.issue_type == "epic" and .status != "closed")][0].id // empty')
if [ -n "$epic" ]; then
	printf 'reusing epic %s\n' "$epic"
elif [ "$dry_run" = 1 ]; then
	epic="<new epic: $problem>"
else
	epic=$(bd create "$problem" -t epic -p 1 \
		--label pig-swarm --label "swarm:$slug" \
		--description "$problem" --silent) || die "could not create the epic"
	printf 'created epic %s\n' "$epic"
fi

slot_ids=()
slot_titles=()
slot_parts=()
for ((i = 1; i <= workers; i++)); do
	if [ "${#parts[@]}" -gt 0 ]; then
		part=${parts[$((i - 1))]}
		title="part $i/$workers: ${part%%：*}"
	else
		part='整个问题由你独立完成一份：不要等别的 worker，也不要假设有人接了下半段。'
		who=$(model_for "$i")
		title="attempt $i/$workers: ${who:-default model}"
	fi
	slot_titles+=("$title")
	slot_parts+=("$part")

	# An open child for this slot is work that never finished: claim it again rather
	# than stacking a duplicate on top of it.
	id=
	if [ "$dry_run" = 0 ]; then
		id=$(bd list --parent "$epic" --all --flat --json 2>/dev/null |
			jq -r --arg l "slot:$i" \
				'[.[] | select(.status != "closed" and (.labels // [] | index($l)))][0].id // empty')
	fi
	if [ -n "$id" ]; then
		printf 'reusing slot %s/%s %s\n' "$i" "$workers" "$id"
	elif [ "$dry_run" = 1 ]; then
		id="<new slot $i>"
	else
		id=$(bd create "$title" -t task -p 1 \
			--parent "$epic" --label pig-swarm --label "slot:$i" \
			--description "$part" --silent) || die "could not create slot $i"
		printf 'created slot %s/%s %s\n' "$i" "$workers" "$id"
	fi
	slot_ids+=("$id")
done

# One tree and one branch per worker, so two of them editing the same file cannot
# race. An existing one is reused, which is what retrying a single slot does.
workdir_of=()
branch_of=()
for ((i = 1; i <= workers; i++)); do
	if [ "$isolate" = 0 ]; then
		workdir_of[i]=$repo
		branch_of[i]=
		continue
	fi
	workdir_of[i]=$out/worktrees/w$i
	branch_of[i]="swarm/$slug/w$i"
	[ "$dry_run" = 1 ] && continue
	if [ -e "${workdir_of[$i]}/.git" ]; then
		printf 'reusing worktree %s\n' "${workdir_of[$i]}"
		continue
	fi
	git -C "$repo" worktree add -b "${branch_of[$i]}" "${workdir_of[$i]}" HEAD >/dev/null ||
		die "could not create a worktree for w$i"
	printf 'worktree %s on branch %s\n' "${workdir_of[$i]}" "${branch_of[$i]}"
done

# The brief. bd is reached with -C so a worker inside a worktree still writes to the
# repository's ledger, not to nothing.
write_prompt() {
	local i=$1 id=$2
	local file=$out/logs/w$1.prompt.md draft=$out/logs/w$1.delivery.md
	{
		printf '# 并行任务 %s/%s\n\n' "$i" "$workers"
		printf '你是并行工作者 #%s。\n\n' "$i"
		printf '## 要解决的问题\n\n%s\n\n' "$problem"
		printf '## 你负责的部分\n\n%s\n\n' "${slot_parts[$((i - 1))]}"
		printf '## 你的账本条目\n\n'
		printf -- '- issue：\x60%s\x60（父 epic：\x60%s\x60，只读）\n' "$id" "$epic"
		printf -- '- 仓库：\x60%s\x60；bd 一律写成 \x60bd -C %s …\x60\n' "$repo" "$repo"
		printf -- '- 你的工作目录：\x60%s\x60\n' "${workdir_of[$i]}"
		if [ "$isolate" = 1 ]; then
			printf -- '- 你的分支：\x60%s\x60\n' "${branch_of[$i]}"
		fi
		printf -- '- 交付草稿写到：\x60%s\x60\n\n' "$draft"
		cat <<'PROTOCOL'
## 协议

1. 先认领，否则别的 worker 会重复干你的活：`bd -C <仓库> update <issue> --claim`
2. 干活，直到你负责的部分真的做完。做完指可验证的完成，不是看起来差不多了。
3. 交付写进 issue：先把内容写进上面那个草稿文件，再

   `bd -C <仓库> comments add <issue> -f <草稿的绝对路径>`

   草稿要有：做了什么、验证证据（命令与输出、`文件:行`、URL）、还没做完或做不了的部分。
4. 贴完关闭：`bd -C <仓库> close <issue>`
5. 最后回一行摘要，别复述全文。

## 禁止

- 不碰别人的 issue，不新建 issue，不关闭父 epic。
- 不执行 git push、bd dolt push、bd import。
- 不写"建议进一步研究"这类空话：要么交付，要么写清楚卡在哪。
PROTOCOL
		if [ "$isolate" = 1 ]; then
			cat <<'WRITEMODE'
- 只改你工作目录里的文件，并提交到你的分支；不切分支、不 rebase、不动别人的分支。
WRITEMODE
		else
			cat <<'READONLY'
- 这一轮是只读的：不改仓库里的任何文件。要改动就把 patch 或确切的步骤写进交付。
READONLY
		fi
	} >"$file"
}

# A worker behind a log file: no screen to watch, so pig's JSON event stream is
# piped through the renderer and the transcript becomes the log.
write_logs_runner() {
	local i=$1 id=$2 m
	local runner=$out/logs/w$1.logs.sh
	m=$(model_for "$i")
	write_prompt "$i" "$id"
	# SC2016: the $ in these single-quoted formats belongs to the generated script.
	# shellcheck disable=SC2016
	{
		printf '#!/usr/bin/env bash\n'
		printf '# Generated by pig-swarm: worker %s (%s).\n' "$i" "$id"
		printf 'set -uo pipefail\n'
		printf 'cd %q || exit 1\n' "${workdir_of[$i]}"
		printf 'printf "%%s\\n\\n" %q\n' "=== ${slot_titles[$((i - 1))]}  $id"
		printf 'pig --mode json %q --name %q --session-dir %q' \
			"@$out/logs/w$i.prompt.md" "swarm-$slug-w$i" "$out/sessions/w$i"
		[ -n "$m" ] && printf ' --model %q' "$m"
		[ -n "$approve_flag" ] && printf ' %s' "$approve_flag"
		printf ' \\\n\t| jq -j --unbuffered -f %q\n' "$out/render.jq"
		# PIPESTATUS[0] is pig's status: jq's would hide a failed run.
		printf 'rc=${PIPESTATUS[0]}\n'
		printf 'printf "\\n[worker %s exit %%s]\\n" "$rc"\n' "$i"
		printf 'printf "%%s" "$rc" >%q\n' "$out/logs/w$i.rc"
	} >"$runner"
	chmod +x "$runner"
	runner_of[i]=$runner
	printf '%s\t%s\n' "$id" "$runner" >>"$out/plan.txt"
}

# A worker in a pane: the real pig session, TUI and all. The brief goes in as a
# positional @file message, which pig sends as the first turn as the TUI opens, so
# nothing has to be typed into a pane that may not be listening yet.
write_tui_runner() {
	local i=$1 id=$2 m
	local runner=$out/logs/w$1.tui.sh
	m=$(model_for "$i")
	write_prompt "$i" "$id"
	{
		printf '#!/usr/bin/env bash\n'
		printf '# Generated by pig-swarm: worker %s (%s), as a pig session.\n' "$i" "$id"
		printf 'set -uo pipefail\n'
		printf 'cd %q || exit 1\n' "${workdir_of[$i]}"
		printf 'exec pig %q --name %q --session-dir %q' \
			"@$out/logs/w$i.prompt.md" "swarm-$slug-w$i" "$out/sessions/w$i"
		[ -n "$m" ] && printf ' --model %q' "$m"
		[ -n "$approve_flag" ] && printf ' %s' "$approve_flag"
		printf '\n'
	} >"$runner"
	chmod +x "$runner"
	runner_of[i]=$runner
	printf '%s\t%s\n' "$id" "$runner" >>"$out/plan.txt"
}

# Sets token to whatever wait_worker has to reap.
launch_logs() {
	local i=$1
	write_logs_runner "$1" "$2"
	"${runner_of[$i]}" >"$out/logs/w$i.log" 2>&1 </dev/null &
	token=$!
}

# The new pane's share of the space it is made from, as kero's -r takes it: 1/n to
# two decimals. Every ratio here is 1/2 … 1/8, where the rounding is invisible.
share() {
	printf '0.%02d' "$((100 / $1))"
}

# One pane per worker. The first becomes the whole grid region, the rest are split
# off a pane that already exists, so the layout is built from the outside in.
split_pane() {
	local i=$1 dir=$2 ratio=$3 target=$4
	write_tui_runner "$i" "${slot_ids[$((i - 1))]}"
	# -d targets the worker's own directory rather than the invoking pane's: this
	# script may have cd'd, and kero reads the directory from the pane it splits.
	token=$(kero split "$target" "--$dir" -r "$ratio" -d "${workdir_of[$i]}" -- "${runner_of[$i]}") ||
		die "kero split failed for w$i"
	[ -n "$token" ] || die "kero split printed no pane id for w$i"
	pane_of[i]=$token
	printf 'pane %s  w%s  %s  %s\n' "$token" "$i" "${slot_ids[$((i - 1))]}" "${slot_titles[$((i - 1))]}"
}

issue_closed() {
	[ "$(bd show "$1" --json 2>/dev/null | jq -r '.[0].status // ""')" = closed ]
}

# A pig session does not exit when the work is done, so closed is the done signal:
# the issue the worker was told to close. Pane status only paces the wait, and a
# worker that goes idle without closing is asked three times over before it is
# called a failure -- a worker blocked on something and one that answered without
# finishing the protocol look exactly alike.
wait_pane() {
	local p=$1 issue=$2 round=0 g
	while [ "$round" -lt 3 ]; do
		round=$((round + 1))
		issue_closed "$issue" && return 0
		kero wait "$p" --for working --timeout 180s >/dev/null 2>&1
		kero wait "$p" --for idle,error,exited >/dev/null 2>&1
		for ((g = 0; g < 15; g++)); do
			issue_closed "$issue" && return 0
			sleep 2
		done
	done
	return 1
}

wait_worker() {
	local i=$1 t=$2
	if [ "$display" = panes ]; then
		if wait_pane "$t" "${slot_ids[$((i - 1))]}"; then
			echo 0 >"$out/logs/w$i.rc"
		else
			echo 1 >"$out/logs/w$i.rc"
		fi
	else
		wait "$t" 2>/dev/null
		[ -s "$out/logs/w$i.rc" ] || echo 1 >"$out/logs/w$i.rc"
	fi
}

# A grid, not a stack: as many columns as a square needs, filled column by column,
# with the remainder spread over the first columns so that no cell is left empty.
# Four workers are a 田, three are a 2 + 1 column pair, nine are a square again. The
# pane this runs in gives most of its height to the grid and keeps the rest for the
# report, so nothing is squeezed to a strip the way a stack of splits squeezes it.
# The share is large on purpose: the panes are the point, and the report path is all
# this pane still has to show.
grid_share=0.85
grid_cols=1
while [ $((grid_cols * grid_cols)) -lt "$workers" ]; do grid_cols=$((grid_cols + 1)); done
# A column count that ignores the terminal shape makes narrow, unreadable cells: on a
# pane taller than it is wide, one column fewer keeps each cell usable. Never below
# one, and the row counts below are recomputed for whatever this settles on.
if [ "$grid_cols" -gt 1 ]; then
	if size=$(stty size 2>/dev/null </dev/tty) && [ -n "$size" ]; then
		term_rows=${size%% *}
		term_cols=${size#* }
		if [ "$term_rows" -gt $((term_cols * 2 / 3)) ]; then
			grid_cols=$((grid_cols - 1))
		fi
	fi
fi
grid_base=$((workers / grid_cols))
grid_extra=$((workers % grid_cols))
grid_rows_of=()
for ((c = 1; c <= grid_cols; c++)); do
	if [ "$c" -le "$grid_extra" ]; then
		grid_rows_of[c]=$((grid_base + 1))
	else
		grid_rows_of[c]=$grid_base
	fi
done

if [ "$dry_run" = 1 ]; then
	printf '\n--- plan (dry run, nothing created) ---\n'
	printf 'problem: %s\ndisplay: %s, repo: %s, epic: %s\n' \
		"$problem" "$display" "$repo" "$epic"
	for ((i = 0; i < workers; i++)); do
		printf 'slot %s: %s — %s\n' "$((i + 1))" "${slot_ids[$i]}" "${slot_titles[$i]}"
	done
	if [ "$display" = panes ]; then
		printf 'layout: %s column(s), rows %s — the grid splits off this pane\n' \
			"$grid_cols" "${grid_rows_of[*]}"
	fi
	if [ "$isolate" = 1 ]; then
		printf 'worktrees: %s/worktrees/w1..%s on branches swarm/%s/w1..%s\n' \
			"$out" "$workers" "$slug" "$workers"
	fi
	printf 'output: %s\n' "$out"
	printf '\nbrief for slot 1:\n\n'
	write_prompt 1 "<slot id>"
	cat "$out/logs/w1.prompt.md"
	exit 0
fi

# Everyone at once: a concurrency cap would only exist to dodge rate limits, and
# lowering -n does that better than a second knob.
tokens=()
if [ "$display" = panes ]; then
	# Column by column, first worker of each column, then the rows below it. Columns
	# have to be finished before any row is split, because a split applies to one
	# pane: splitting column 1 downward first would leave it shorter than the grid
	# and the next column would only span that one cell.
	first_of=()
	acc=1
	for ((c = 1; c <= grid_cols; c++)); do
		first_of[c]=$acc
		acc=$((acc + grid_rows_of[c]))
	done

	split_pane "${first_of[1]}" down "$grid_share" "$KERO_PANE"
	region=$token
	col_pane[1]=$region
	for ((c = 2; c <= grid_cols; c++)); do
		split_pane "${first_of[c]}" right "$(share $((grid_cols - c + 2)))" "$region"
		col_pane[c]=$token
	done
	for ((c = 1; c <= grid_cols; c++)); do
		for ((r = 2; r <= grid_rows_of[c]; r++)); do
			split_pane "$((first_of[c] + r - 1))" down \
				"$(share $((grid_rows_of[c] - r + 2)))" "${col_pane[c]}"
		done
	done
	# Every pane id was recorded by its own worker number as it was created.
	for ((n = 1; n <= workers; n++)); do tokens[n]="${pane_of[$n]}"; done
else
	for ((n = 1; n <= workers; n++)); do
		launch_logs "$n" "${slot_ids[$((n - 1))]}"
		tokens[n]=$token
	done
fi
for ((n = 1; n <= workers; n++)); do
	wait_worker "$n" "${tokens[n]}"
done

failed=()
for ((i = 1; i <= workers; i++)); do
	rc=$(cat "$out/logs/w$i.rc" 2>/dev/null || echo 1)
	[ "$rc" -eq 0 ] || failed+=("w$i(rc=$rc)")
done

# The report is assembled from the ledger, not from the workers' stdout: a worker
# that published its delivery and then crashed has still delivered it.
report=$out/report.md
{
	printf '# pig-swarm: %s\n\n' "$problem"
	printf -- '- epic: \x60%s\x60\n' "$epic"
	printf -- '- workers: %s, models: %s, display: %s\n' \
		"$workers" "${models:-default}" "$display"
	printf -- '- output: \x60%s\x60\n' "$out"
	printf -- '- worker exits: %s\n\n' "${failed[*]:-all clean}"
	for ((i = 0; i < workers; i++)); do
		id=${slot_ids[$i]}
		printf '## %s — %s\n\n' "$id" "${slot_titles[$i]}"
		printf 'status: %s\n\n' "$(bd show "$id" --json 2>/dev/null | jq -r '.[0].status // "unknown"')"
		if [ "$isolate" = 1 ]; then
			printf 'worktree: %s\nbranch: %s\n\n' \
				"${workdir_of[$((i + 1))]}" "${branch_of[$((i + 1))]}"
		fi
		body=$(bd comments "$id" --json 2>/dev/null | jq -r 'map(.text) | join("\n\n")')
		printf '%s\n\n' "${body:-(没有留下交付，看 logs/w$((i + 1)).log)}"
	done
} >"$report"

printf '\n=== report: %s\n' "$report"
if [ "$display" = panes ]; then
	for ((i = 1; i <= workers; i++)); do
		printf '  w%s → pane %s\n' "$i" "${pane_of[$i]:-}"
	done
	printf '\neach pane is a live pig session: keep talking to it, or close it with kero close %s\n' \
		"${pane_of[*]}"
else
	for ((i = 1; i <= workers; i++)); do
		printf '\n--- w%s log tail\n' "$i"
		tail -n 4 "$out/logs/w$i.log" 2>/dev/null
	done
fi
if [ "$isolate" = 1 ]; then
	printf '\nbranches to review: %s\nmerge one with: git merge <branch>\n' \
		"${branch_of[*]:1}"
fi

[ "${#failed[@]}" -eq 0 ] ||
	die "workers failed: ${failed[*]}; re-run the same command to retry only the open slots"
printf '\nall %s workers finished; epic %s\n' "$workers" "$epic"

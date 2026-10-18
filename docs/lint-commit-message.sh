#!/usr/bin/env bash
# 校验提交信息是否符合 docs/commit-style.md，即 Conventional Commits 1.0.0 的落地档。
# 用法: lint-commit-message.sh <file>...   |   git log -1 --format=%B | lint-commit-message.sh
# 退出码: 0 合规, 1 违规, 2 用法错误

set -u

# 长度按字符计，不按字节，否则在 C locale 下汉字会被算成三倍。
for candidate in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
	if [ "$(LC_ALL=$candidate bash -c 'x=一; printf %s "${#x}"' 2>/dev/null)" = 1 ]; then
		export LC_ALL=$candidate
		break
	fi
done

types='feat|fix|build|chore|ci|docs|perf|refactor|revert|style|test'
header_max=100
subject_warn=60
header_re="^($types)(\([a-z0-9.+-]+\))?!?: .+"

fail=0

report() {
	printf '%s:%s: %s\n' "$1" "$2" "$3" >&2
	fail=1
}

note() {
	printf '%s:%s: 提示：%s\n' "$1" "$2" "$3" >&2
}

check() {
	local src=$1 text=$2
	if [ -z "${text//[[:space:]]/}" ]; then
		report "$src" 1 "提交信息为空"
		return
	fi

	local header=${text%%$'\n'*}
	local body=
	if [ "$header" != "$text" ]; then
		body=${text#*$'\n'}
	fi

	if ! [[ $header =~ $header_re ]]; then
		report "$src" 1 "header 不是 <type>(<scope>)!: <description>：$header"
	fi

	local len=${#header}
	if [ "$len" -gt "$header_max" ]; then
		report "$src" 1 "header 长 $len 字符，上限 $header_max"
	elif [ "$len" -gt "$subject_warn" ]; then
		note "$src" 1 "header 长 $len 字符，建议不超过 $subject_warn"
	fi

	local subject=$header
	case $subject in
	*': '*) subject=${subject#*: } ;;
	esac
	subject=${subject%"${subject##*[![:space:]]}"}
	case $subject in
	*.) report "$src" 1 "description 不应以句号结尾" ;;
	*。) report "$src" 1 "description 不应以句号结尾" ;;
	esac

	if [ -n "$body" ]; then
		if [ -n "${body%%$'\n'*}" ]; then
			report "$src" 2 "header 之后应紧跟一个空行"
		fi
		local lineno=2 line
		while IFS= read -r line; do
			lineno=$((lineno + 1))
			[ -z "$line" ] && continue
			if [ "${#line}" -gt "$header_max" ] && ! printf '%s' "$line" | grep -qE 'https?://'; then
				report "$src" "$lineno" "行长 ${#line} 字符，上限 $header_max"
			fi
		done <<< "$body"
	fi
}

run() {
	local src=$1 input
	input=$(cat)
	check "$src" "$input"
}

if [ $# -eq 0 ]; then
	run stdin
else
	for file in "$@"; do
		if [ "$file" = - ]; then
			run stdin
		elif [ ! -r "$file" ]; then
			printf '%s: 无法读取\n' "$file" >&2
			exit 2
		else
			run "$file" < "$file"
		fi
	done
fi

exit "$fail"

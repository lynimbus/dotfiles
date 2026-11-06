#!/usr/bin/env bash
# test_inventory_data.sh — data-integrity guard for committed inventory/seed files.
#
#   Standalone: bash tests/test_inventory_data.sh
#   Suite mode: bash tests/run.sh inventory_data
#
# QQ is IMAGE-OWNED: build_files/build.sh installs the native Tencent payload
# plus the linuxqq-wayland-fix wrapper. Commit 378a932 removed com.qq.QQ from
# the first-boot seed list and added assertions to test_flatpak.sh, but forgot
# to ablate the stale object in apps/flatpak/inventory/bazzite.json. This suite
# validates EVERY committed inventory/seed data file so that drift cannot come
# back through a new profile, a Brewfile, a container inventory or a seed list:
#
#   * apps/flatpak/inventory/*.json  — parseable, version 1, every apps[] entry
#     carries application/origin/installation/branch/arch, no duplicate ids
#   * containers/inventory/*.json   — parseable, version 1
#   * apps/brew/inventory/*/Brewfile — parseable Homebrew Bundle directives
#   * all of the above + apps/profiles/* seed lists + leaves files — no QQ id
#
# INVENTORY_DATA_ROOT is an optional override used by the mutation self-test
# at the bottom: it re-runs THIS script against a throwaway copy of the data
# tree with a com.qq.QQ entry re-added, and asserts that the guard fails.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="${REPO_ROOT}/tests/$(basename "${BASH_SOURCE[0]}")"
DATA_ROOT="${INVENTORY_DATA_ROOT:-${REPO_ROOT}}"
SKIP_SELFTEST="${INVENTORY_DATA_SKIP_SELFTEST:-0}"
QQ_ID='com.qq.QQ'

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

# layerfs `exec` points TMPDIR at a scratch dir that is not always present.
if [[ ! -d "${TMPDIR:-/tmp}" || ! -w "${TMPDIR:-/tmp}" ]]; then
    export TMPDIR=/tmp
fi

# ── discovery ────────────────────────────────────────────────────────────
# "Committed" means git-tracked when this checkout is a git work tree. The
# find fallback keeps the suite usable in source snapshots / layerfs branches
# that carry no .git directory (and in the mutation self-test's temp tree).
DATA_DIRS=(apps/flatpak/inventory containers/inventory apps/brew/inventory apps/profiles)
ALL_FILES=()

git_top=""
if command -v git >/dev/null 2>&1; then
    git_top="$(git -C "${REPO_ROOT}" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -n "$git_top" && "$DATA_ROOT" == "$REPO_ROOT" ]] &&
   [[ "$(cd "$git_top" 2>/dev/null && pwd -P)" == "$(cd "$REPO_ROOT" && pwd -P)" ]]; then
    while IFS= read -r -d '' rel; do
        ALL_FILES+=("$rel")
    done < <(git -C "$REPO_ROOT" ls-files -z --full-name -- "${DATA_DIRS[@]}")
else
    find_roots=()
    for d in "${DATA_DIRS[@]}"; do
        [[ -d "$DATA_ROOT/$d" ]] && find_roots+=("$DATA_ROOT/$d")
    done
    if ((${#find_roots[@]})); then
        while IFS= read -r -d '' abs; do
            ALL_FILES+=("${abs#"$DATA_ROOT"/}")
        done < <(find "${find_roots[@]}" -type f -print0 2>/dev/null)
    fi
fi

if ((${#ALL_FILES[@]})); then
    mapfile -t ALL_FILES < <(printf '%s\n' "${ALL_FILES[@]}" | LC_ALL=C sort)
fi

FLATPAK_JSONS=()
CONTAINER_JSONS=()
BREWFILES=()
SCAN_FILES=()

for rel in "${ALL_FILES[@]}"; do
    [[ -f "$DATA_ROOT/$rel" ]] || continue
    base="${rel##*/}"
    [[ "$base" == .* ]] && continue   # .gitkeep placeholders are not data
    [[ "$base" == *.md ]] && continue # profiles/README.md is prose, not data
    case "$rel" in
        apps/flatpak/inventory/*.json)  FLATPAK_JSONS+=("$rel") ;;
        containers/inventory/*.json)   CONTAINER_JSONS+=("$rel") ;;
        apps/brew/inventory/*/Brewfile) BREWFILES+=("$rel") ;;
    esac
    case "$rel" in
        apps/flatpak/inventory/*|containers/inventory/*|apps/brew/inventory/*|apps/profiles/*)
            SCAN_FILES+=("$rel") ;;
    esac
done

# ── validators (each prints a reason and returns non-zero on failure) ─────
json_version_1() {
    python3 - "$1" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    print("unreadable JSON: %s" % exc)
    sys.exit(1)
if not isinstance(data, dict):
    print("top-level value is not a JSON object")
    sys.exit(1)
if data.get("version") != 1:
    print("version is %r, expected 1" % data.get("version"))
    sys.exit(1)
PY
}

flatpak_required_fields() {
    python3 - "$1" <<'PY'
import json, sys
REQUIRED = ("application", "origin", "installation", "branch", "arch")
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    print("unreadable JSON: %s" % exc)
    sys.exit(1)
apps = data.get("apps") if isinstance(data, dict) else None
if not isinstance(apps, list):
    print("missing or non-list 'apps' array")
    sys.exit(1)
for i, app in enumerate(apps):
    if not isinstance(app, dict):
        print("apps[%d] is not an object" % i)
        sys.exit(1)
    missing = [k for k in REQUIRED
               if not isinstance(app.get(k), str) or not app[k].strip()]
    if missing:
        print("apps[%d] (%r) missing/blank: %s"
              % (i, app.get("application"), ", ".join(missing)))
        sys.exit(1)
PY
}

flatpak_unique_ids() {
    python3 - "$1" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    print("unreadable JSON: %s" % exc)
    sys.exit(1)
apps = data.get("apps") if isinstance(data, dict) else None
if not isinstance(apps, list):
    print("missing or non-list 'apps' array")
    sys.exit(1)
seen, dupes = set(), []
for app in apps:
    app_id = str(app.get("application")) if isinstance(app, dict) else "<non-object>"
    if app_id in seen and app_id not in dupes:
        dupes.append(app_id)
    seen.add(app_id)
if dupes:
    print("duplicate application ids: %s" % ", ".join(dupes))
    sys.exit(1)
PY
}

brewfile_parseable() {
    python3 - "$1" <<'PY'
import re, sys
KEYWORD = re.compile(r"^\s*(brew|cask|tap|mas|vscode|whalebrew|cask_args)\b")
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()
except Exception as exc:
    print("unreadable Brewfile: %s" % exc)
    sys.exit(1)

def code_part(line):
    """Strip a trailing comment without cutting inside a quoted name."""
    chars, quote = [], None
    for ch in line:
        if quote:
            chars.append(ch)
            if ch == quote:
                quote = None
        elif ch in ('"', "'"):
            quote = ch
            chars.append(ch)
        elif ch == '#':
            break
        else:
            chars.append(ch)
    return ''.join(chars).rstrip(), quote

for lineno, raw in enumerate(lines, 1):
    line = raw.rstrip("\n")
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    code, open_quote = code_part(line)
    if open_quote:
        print("line %d: unbalanced quote" % lineno)
        sys.exit(1)
    if not KEYWORD.match(code):
        print("line %d: not a Homebrew Bundle directive: %r" % (lineno, line.strip()))
        sys.exit(1)
    for opener, closer in (("(", ")"), ("[", "]"), ("{", "}")):
        if code.count(opener) != code.count(closer):
            print("line %d: unbalanced %s%s" % (lineno, opener, closer))
            sys.exit(1)
    if not re.search(r'''["']''', code):
        print("line %d: directive has no quoted name" % lineno)
        sys.exit(1)
PY
}

flatpak_origins_declared() {
    python3 - "$1" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    print("unreadable JSON: %s" % exc)
    sys.exit(1)
remotes = data.get("remotes") if isinstance(data, dict) else None
names = set()
if isinstance(remotes, dict):
    for scope in ("user", "system"):
        for entry in remotes.get(scope) or []:
            if isinstance(entry, dict) and isinstance(entry.get("name"), str):
                names.add(entry["name"])
apps = data.get("apps") if isinstance(data, dict) else None
if not isinstance(apps, list):
    print("missing or non-list 'apps' array")
    sys.exit(1)
undeclared = [app.get("origin")
              for app in apps
              if isinstance(app, dict) and app.get("origin") not in names]
if undeclared:
    print("undeclared origin(s): %s (declared: %s)"
          % (", ".join(sorted({str(o) for o in undeclared})),
             ", ".join(sorted(names)) or "none"))
    sys.exit(1)
PY
}

flatpak_apps_nonempty() {
    python3 - "$1" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh)
except Exception as exc:
    print("unreadable JSON: %s" % exc)
    sys.exit(1)
apps = data.get("apps") if isinstance(data, dict) else None
if not isinstance(apps, list):
    print("missing or non-list 'apps' array")
    sys.exit(1)
if not apps:
    print("'apps' array is empty")
    sys.exit(1)
PY
}

t_title "committed inventory data"

t_case "python3 is available for the JSON/Brewfile validators"
if command -v python3 >/dev/null 2>&1; then t_ok; else t_fail "python3 not found in PATH"; fi

t_case "committed inventory/seed data files are discoverable"
if ((${#SCAN_FILES[@]} > 0)); then t_ok; else t_fail "no data files found under ${DATA_ROOT}"; fi

t_case "all discovered committed files still exist on disk"
missing=()
for rel in "${ALL_FILES[@]}"; do
    [[ -f "$DATA_ROOT/$rel" ]] || missing+=("$rel")
done
if ((${#missing[@]} == 0)); then t_ok; else t_fail "missing: ${missing[*]}"; fi

t_case "flatpak inventory for the bazzite profile is present"
assert_file_exists "bazzite.json" "$DATA_ROOT/apps/flatpak/inventory/bazzite.json"

t_case "flatpak first-boot seed list is present"
assert_file_exists "base.flatpak.txt" "$DATA_ROOT/apps/profiles/base.flatpak.txt"

# ── runner behaviour ─────────────────────────────────────────────────────
t_case "run.sh rejects an unknown suite"
# Auto-discovery must not turn a typo into a silent no-op: an undiscovered
# suite name is a hard usage error (exit 2), never a green run.
bash "${REPO_ROOT}/tests/run.sh" definitely_not_a_suite >/dev/null 2>&1
rc=$?
assert_eq "unknown suite exit code" "2" "$rc"

# ── per-file structural integrity ────────────────────────────────────────
for rel in "${FLATPAK_JSONS[@]}"; do
    f="$DATA_ROOT/$rel"

    t_case "$rel: parseable JSON"
    if python3 -m json.tool "$f" >/dev/null 2>&1; then t_ok; else t_fail "python3 -m json.tool rejects it"; fi

    t_case "$rel: version == 1"
    if out="$(json_version_1 "$f" 2>&1)"; then t_ok; else t_fail "$out"; fi

    t_case "$rel: every apps[] entry has application/origin/installation/branch/arch"
    if out="$(flatpak_required_fields "$f" 2>&1)"; then t_ok; else t_fail "$out"; fi

    t_case "$rel: no duplicate application ids"
    if out="$(flatpak_unique_ids "$f" 2>&1)"; then t_ok; else t_fail "$out"; fi
done

t_case "every app origin is declared in remotes"
# restore.sh only adds the remotes listed in the inventory. An app whose
# `origin` is not one of those names can never be installed on a fresh
# machine, so a mismatch is a real restore bug rather than a data typo.
origin_errors=""
for rel in "${FLATPAK_JSONS[@]}"; do
    if ! out="$(flatpak_origins_declared "$DATA_ROOT/$rel" 2>&1)"; then
        origin_errors+="${rel}: ${out}; "
    fi
done
if [[ -z "$origin_errors" ]]; then t_ok; else t_fail "undeclared origins: ${origin_errors}"; fi

t_case "every committed flatpak inventory has a non-empty apps[] array"
# An accidentally emptied apps[] list passes the field, duplicate-id and
# origin validators above, yet restore.sh would silently install nothing.
empty_errors=""
for rel in "${FLATPAK_JSONS[@]}"; do
    if ! out="$(flatpak_apps_nonempty "$DATA_ROOT/$rel" 2>&1)"; then
        empty_errors+="${rel}: ${out}; "
    fi
done
if [[ -z "$empty_errors" ]]; then t_ok; else t_fail "empty flatpak inventory: ${empty_errors}"; fi

for rel in "${CONTAINER_JSONS[@]}"; do
    f="$DATA_ROOT/$rel"

    t_case "$rel: parseable JSON"
    if python3 -m json.tool "$f" >/dev/null 2>&1; then t_ok; else t_fail "python3 -m json.tool rejects it"; fi

    t_case "$rel: version == 1"
    if out="$(json_version_1 "$f" 2>&1)"; then t_ok; else t_fail "$out"; fi
done

for rel in "${BREWFILES[@]}"; do
    f="$DATA_ROOT/$rel"

    t_case "$rel: parseable Homebrew Bundle directives"
    if out="$(brewfile_parseable "$f" 2>&1)"; then t_ok; else t_fail "$out"; fi
done

# ── image-owned QQ must be absent from EVERY inventory/seed data file ─────
for rel in "${SCAN_FILES[@]}"; do
    t_case "$rel: no image-owned ${QQ_ID}"
    if grep -qF -- "$QQ_ID" "$DATA_ROOT/$rel"; then
        t_fail "$rel: IMAGE-OWNED app id ${QQ_ID} is forbidden in committed inventory/seed data"
    else
        t_ok
    fi
done

# ── mutation self-test: the guard must catch a re-added QQ entry ──────────
# Build a throwaway copy of the whole committed data tree, re-inject exactly
# the ablation target, then run THIS suite against the copy and require a
# non-zero exit caused specifically by the QQ guard. Nothing in the repo is
# touched: only the temp copy is mutated, and it is deleted afterwards.
if [[ "$SKIP_SELFTEST" != "1" && "$DATA_ROOT" == "$REPO_ROOT" ]]; then
    t_case "ablation regression: re-adding ${QQ_ID} makes this suite fail"
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/aw-inventory-data-XXXXXX" 2>/dev/null || true)"
    if [[ -z "$tmp" || ! -d "$tmp" ]]; then
        t_fail "could not create the mutation fixture directory"
    else
        fixture="$tmp/apps/flatpak/inventory/bazzite.json"
        for rel in "${SCAN_FILES[@]}"; do
            mkdir -p "$tmp/$(dirname "$rel")"
            cp -p "$DATA_ROOT/$rel" "$tmp/$rel"
        done
        python3 - "$fixture" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
data = json.loads(p.read_text(encoding="utf-8"))
data["apps"].append({
    "application": "com.qq.QQ",
    "origin": "flathub",
    "installation": "system",
    "branch": "stable",
    "arch": "x86_64",
})
p.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
        if ! grep -qF -- "$QQ_ID" "$fixture"; then
            t_fail "mutation fixture does not contain ${QQ_ID}"
        else
            child_out="$(INVENTORY_DATA_ROOT="$tmp" INVENTORY_DATA_SKIP_SELFTEST=1 \
                        bash "$SCRIPT_PATH" 2>&1)"
            rc=$?
            if [[ $rc -ne 0 && "$child_out" == *"IMAGE-OWNED"* && "$child_out" == *"$QQ_ID"* ]]; then
                t_ok
            else
                t_fail "guard did not reject the re-added ${QQ_ID} (rc=$rc): ${child_out//$'\n'/ | }"
            fi
        fi
        rm -rf "$tmp"
    fi
fi

printf 'inventory data: %d checks, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED"
if (( TESTS_FAILED > 0 )); then
    exit 1
fi
exit 0

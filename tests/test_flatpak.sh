#!/usr/bin/env bash
# test_flatpak.sh — end-to-end tests for the flatpak inventory using mock-flatpak.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

CAPTURE="${REPO_ROOT}/apps/flatpak/capture.sh"
RESTORE="${REPO_ROOT}/apps/flatpak/restore.sh"
INV_PY="${REPO_ROOT}/apps/flatpak/inventory.py"

seed() { # seed <scope> <app> <origin> [branch]
    local scope="$1" app="$2" origin="$3" branch="${4:-stable}"
    flatpak remote-add --if-not-exists --"$scope" "$origin" "https://example.com/$origin/"
    flatpak install --"$scope" --assumeyes "$origin" "$app//$branch"
}

t_title "flatpak inventory"

t_setup
INV="$ATOMIC_WS_ROOT/apps/flatpak/inventory/${WORKSTATION_PROFILE}.json"
rm -f "$INV"

t_case "capture with zero apps produces valid, empty inventory"
bash "$CAPTURE" >/dev/null 2>&1
assert_contains "schema version" '"version": 1' "$INV"
assert_contains "empty user remotes" '"user": []' "$INV"
assert_contains "empty system remotes" '"system": []' "$INV"
assert_contains "empty apps" '"apps": []' "$INV"

t_case "capture records app, origin, branch and install scope (user + system)"
seed system org.mozilla.firefox flathub
seed system com.visualstudio.code flathub
seed user com.spotify.Client flathub beta
seed user org.videolan.VLC fedora
bash "$CAPTURE" >/dev/null 2>&1
assert_contains "system app" '"application": "com.visualstudio.code"' "$INV"
assert_contains "system scope" '"installation": "system"' "$INV"
assert_contains "user app" '"application": "com.spotify.Client"' "$INV"
assert_contains "user scope" '"installation": "user"' "$INV"
assert_contains "branch captured" '"branch": "beta"' "$INV"
assert_contains "origin captured" '"origin": "fedora"' "$INV"
assert_contains "flathub url recorded" 'https://example.com/flathub/' "$INV"

t_case "capture skips an app that duplicates something the image owns"
# the sandboxed fcitx5 app really is installed on machines that still have it;
# recording it would make restore.sh install the duplicate on a fresh machine
seed system org.fcitx.Fcitx5 flathub
out=$(bash "$CAPTURE" 2>&1)
assert_not_contains "sandboxed fcitx5 not recorded" '"application": "org.fcitx.Fcitx5"' "$INV"
assert_contains "conflict explained" "sandboxed fcitx5 daemon" "$out"
assert_contains "uninstall command suggested" "flatpak uninstall --system -y" "$out"
grep -v 'org.fcitx.Fcitx5' "$MOCK_STATE/flatpak/system/apps.tsv" >"$MOCK_STATE/flatpak/system/apps.tsv.tmp"
mv "$MOCK_STATE/flatpak/system/apps.tsv.tmp" "$MOCK_STATE/flatpak/system/apps.tsv"

t_case "capture is idempotent — second run produces byte-identical file"
cp "$INV" "$T_SANDBOX/inv-before"
bash "$CAPTURE" >/dev/null 2>&1
if cmp -s "$T_SANDBOX/inv-before" "$INV"; then t_ok; else t_fail "re-capture changed the file"; fi

t_case "capture sorts apps deterministically"
sorted=$(python3 -c "import json; d=json.load(open('$INV')); print(','.join(a['application'] for a in d['apps']))")
assert_eq "apps sorted" "com.spotify.Client,com.visualstudio.code,org.mozilla.firefox,org.videolan.VLC" "$sorted"

t_case "capture skips runtime-looking refs even if --app leaks them"
printf 'org.freedesktop.Platform\tflathub\t23.08\tx86_64\n' >>"$MOCK_STATE/flatpak/system/apps.tsv"
printf 'org.freedesktop.SDK\tflathub\t23.08\tx86_64\n' >>"$MOCK_STATE/flatpak/system/apps.tsv"
bash "$CAPTURE" >/dev/null 2>&1
assert_not_contains "runtime .Platform filtered" '"application": "org.freedesktop.Platform"' "$INV"
assert_not_contains "runtime .SDK filtered" '"application": "org.freedesktop.SDK"' "$INV"
grep -v 'org.freedesktop' "$MOCK_STATE/flatpak/system/apps.tsv" >"$MOCK_STATE/flatpak/system/apps.tsv.tmp"
mv "$MOCK_STATE/flatpak/system/apps.tsv.tmp" "$MOCK_STATE/flatpak/system/apps.tsv"

# ── restore ──
t_case "restore on a fresh machine adds remotes and installs apps"
rm -rf "$MOCK_STATE/flatpak"
bash "$RESTORE" >/dev/null 2>&1
sys_apps="$(flatpak list --app --columns=application,origin,installation,branch,arch --system)"
user_apps="$(flatpak list --app --columns=application,origin,installation,branch,arch --user)"
assert_contains "flathub remote re-added (system)" "flathub" "$(flatpak remotes --columns=name,url,options --system)"
assert_contains "firefox re-installed" "org.mozilla.firefox" "$sys_apps"
assert_contains "code re-installed" "com.visualstudio.code" "$sys_apps"
assert_contains "spotify re-installed" "com.spotify.Client" "$user_apps"
assert_contains "vlc re-installed" "org.videolan.VLC" "$user_apps"

t_case "restore is idempotent — second run installs nothing new"
before_sys=$(flatpak list --app --columns=application,origin,installation,branch,arch --system | wc -l)
bash "$RESTORE" >/dev/null 2>&1
after_sys=$(flatpak list --app --columns=application,origin,installation,branch,arch --system | wc -l)
assert_eq "no duplicate installs" "$before_sys" "$after_sys"

t_case "restore refuses to install a conflicting app from a stale inventory"
# a profile captured before the conflict rule existed can still name the
# sandboxed fcitx5 app; restore must skip it instead of reintroducing it
conflict_id=$(INV_PY="$INV_PY" python3 - <<'PYEOF'
import os, re
src = open(os.environ["INV_PY"]).read()
block = re.search(r"CONFLICTS_WITH_IMAGE = \{(.*?)\n\}", src, re.S).group(1)
print(re.search(r'"([^"]+)"', block).group(1))
PYEOF
)
python3 - "$INV" "$conflict_id" <<'PYEOF'
import json, sys, pathlib
p, app_id = pathlib.Path(sys.argv[1]), sys.argv[2]
inv = json.loads(p.read_text())
inv["apps"].append({"application": app_id, "origin": "flathub",
                    "installation": "system", "branch": "stable",
                    "arch": "x86_64"})
p.write_text(json.dumps(inv, indent=2))
PYEOF
out=$(bash "$RESTORE" --dry-run 2>&1)
assert_not_contains "conflicting app not installed" "installing system $conflict_id" "$out"
assert_contains "restore explains the conflict" "duplicates an image component" "$out"
python3 - "$INV" "$conflict_id" <<'PYEOF'
import json, sys, pathlib
p, app_id = pathlib.Path(sys.argv[1]), sys.argv[2]
inv = json.loads(p.read_text())
inv["apps"] = [a for a in inv["apps"] if a["application"] != app_id]
p.write_text(json.dumps(inv, indent=2))
PYEOF

t_case "restore NEVER removes apps that are not in the inventory"
seed system org.extra.Unlisted flathub
bash "$RESTORE" >/dev/null 2>&1
assert_contains "unlisted app survives additive restore" "org.extra.Unlisted" "$(flatpak list --app --columns=application,origin,installation,branch,arch --system)"

t_case "restore fails with a clear error when origin is unknown and has no URL"
python3 - "$INV" <<'PYEOF'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1])
inv = json.loads(p.read_text())
inv["apps"].append({"application": "org.broken.App", "origin": "ghost", "installation": "user", "branch": "stable", "arch": "x86_64"})
p.write_text(json.dumps(inv, indent=2))
PYEOF
out=$(bash "$RESTORE" 2>&1)
rc=$?
if [[ $rc -eq 1 ]]; then t_ok; else t_fail "restore rc: expected 1, got $rc"; fi
assert_contains "error mentions unknown origin" "origin 'ghost'" "$out"

t_case "restore --prune --dry-run lists but does not uninstall"
out=$(bash "$RESTORE" --prune --dry-run 2>&1)
assert_contains "prune dry-run lists unlisted app" "org.extra.Unlisted" "$out"
assert_contains "unlisted app still installed after dry-run" "org.extra.Unlisted" "$(flatpak list --app --columns=application,origin,installation,branch,arch --system)"

t_case "restore --prune asks for confirmation and honours 'no'"
out=$(printf 'no\n' | bash "$RESTORE" --prune 2>&1)
assert_contains "asks for confirmation" "Type 'yes' to UNINSTALL" "$out"
assert_contains "declined prune keeps the app" "org.extra.Unlisted" "$(flatpak list --app --columns=application,origin,installation,branch,arch --system)"

t_case "restore --prune with 'yes' actually uninstalls"
out=$(printf 'yes\n' | bash "$RESTORE" --prune 2>&1)
assert_contains "prune removes unlisted app" "uninstalling org.extra.Unlisted" "$out"
assert_not_contains "app gone after prune" "org.extra.Unlisted" "$(flatpak list --app --columns=application,origin,installation,branch,arch --system)"

t_case "--yes cannot bypass the prune confirmation"
# reset: drop the ghost app from the inventory, re-add the unlisted extra
python3 - "$INV" <<'PYEOF'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1])
inv = json.loads(p.read_text())
inv["apps"] = [a for a in inv["apps"] if a["origin"] != "ghost"]
p.write_text(json.dumps(inv, indent=2))
PYEOF
seed system org.extra.Unlisted flathub
out=$(printf '' | bash "$RESTORE" --prune --yes 2>&1)
rc=$?
if [[ $rc -eq 1 ]]; then t_ok; else t_fail "prune --yes rc: expected 1, got $rc"; fi
assert_contains "explains the refusal" "deliberately ignored" "$out"

t_case "inventory.py imports cleanly; every function still has a caller"
if python3 - "$INV_PY" <<'PYEOF'
import ast, importlib.util, sys
path = sys.argv[1]
spec = importlib.util.spec_from_file_location("aw_inventory_probe", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
required = ["INVENTORY_VERSION", "CONFLICTS_WITH_IMAGE", "APP_COLUMNS",
            "REMOTE_COLUMNS", "_tail", "_run", "_flatpak", "_have_flatpak",
            "_parse_tsv", "_looks_like_runtime", "_conflicts_with_image",
            "_list_apps", "_list_remotes", "_scope_or_warn", "capture",
            "_load", "status", "restore", "main"]
missing = [n for n in required if not hasattr(mod, n)]
if missing:
    raise SystemExit("missing public names: " + ",".join(missing))
tree = ast.parse(open(path, encoding="utf-8").read())
loads = [n.id for n in ast.walk(tree)
         if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)]
dead = [n.name for n in tree.body
        if isinstance(n, ast.FunctionDef) and n.name not in loads]
if dead:
    raise SystemExit("dead functions: " + ",".join(dead))
PYEOF
then
    t_ok
else
    t_fail "inventory.py import/caller probe failed"
fi

t_case "flatpak CLI flags unchanged"
cli_help=$(python3 "$INV_PY" --help 2>&1)
assert_contains "capture subcommand" "capture" "$cli_help"
assert_contains "status subcommand" "status" "$cli_help"
assert_contains "restore subcommand" "restore" "$cli_help"
cli_help=$(python3 "$INV_PY" restore --help 2>&1)
assert_contains "--prune flag" "--prune" "$cli_help"
assert_contains "--dry-run flag" "--dry-run" "$cli_help"
assert_contains "--yes flag" "--yes" "$cli_help"

t_teardown
rm -f "${REPO_ROOT}/apps/flatpak/inventory/testbox.json"

printf '\nflatpak: %d checks, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED" >&2
exit "$TESTS_FAILED"

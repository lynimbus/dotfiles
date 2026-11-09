#!/usr/bin/env bash
# noctalia 配置的新鲜度检查：单属主模板 + 无弃用调色板角色（noctalia 5.4.1）
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
cfg="$repo/home/desktop/noctalia/config.toml"
mod="$repo/home/desktop/noctalia/default.nix"
tmpl="$repo/home/desktop/noctalia/templates"
noctalia_bin="$(command -v noctalia || true)"
[ -x "$noctalia_bin" ] || noctalia_bin=/etc/profiles/per-user/lynimbus/bin/noctalia

assert_line_present() { # file pattern why
  if ! grep -q "$2" "$1"; then echo "FAIL: $3"; return 1; fi
}
assert_line_absent() { # file pattern why
  if grep -q "$2" "$1"; then echo "FAIL: $3"; return 1; fi
}

test_config_validates_with_zero_warnings() {
  local out
  out="$("$noctalia_bin" config validate "$cfg" 2>&1)" || { echo "FAIL: config validate exited nonzero: $out"; return 1; }
  if printf '%s\n' "$out" | grep -q 'WARN '; then echo "FAIL: deprecated keys remain in config.toml: $out"; return 1; fi
}
test_stale_mango_user_template_entry_removed() {
  assert_line_absent "$cfg" 'nyxuri_mango' 'stale user template entry nyxuri_mango still present' || return 1
  assert_line_absent "$cfg" 'noctalia/templates/mango.conf' 'config.toml still references the deleted mango.conf template' || return 1
}
test_deprecated_capsule_border_role_migrated() {
  assert_line_present "$cfg" 'capsule_border = "outline_variant"' 'capsule_border not migrated to outline_variant' || return 1
  assert_line_absent "$cfg" 'capsule_border = "outline"' 'capsule_border still uses deprecated role outline' || return 1
}
test_deprecated_capsule_group_fill_role_migrated() {
  assert_line_present "$cfg" 'fill = "surface_container"' 'capsule_group fill not migrated to surface_container' || return 1
  assert_line_absent "$cfg" 'fill = "surface_variant"' 'capsule_group fill still uses deprecated role surface_variant' || return 1
}
test_stale_mango_template_copy_deleted() {
  if [ -f "$tmpl/mango.conf" ]; then echo "FAIL: stale template copy templates/mango.conf still exists"; return 1; fi
}
test_custom_templates_intact() {
  if [ ! -f "$tmpl/gtk-3.0.css" ]; then echo "FAIL: custom template gtk-3.0.css went missing"; return 1; fi
  if [ ! -f "$tmpl/gtk-4.0.css" ]; then echo "FAIL: custom template gtk-4.0.css went missing"; return 1; fi
  if [ ! -d "$tmpl/fcitx5" ]; then echo "FAIL: custom template dir fcitx5 went missing"; return 1; fi
}
test_default_nix_links_mango_conf_removed_only() {
  assert_line_absent "$mod" 'mango.conf' 'default.nix still links mango.conf' || return 1
  assert_line_present "$mod" '"gtk-3.0.css"' 'default.nix lost the gtk-3.0.css link' || return 1
  assert_line_present "$mod" '"gtk-4.0.css"' 'default.nix lost the gtk-4.0.css link' || return 1
  assert_line_present "$mod" '"fcitx5"' 'default.nix lost the fcitx5 link' || return 1
}
test_flake_check_passes() {
  if ! (cd "$repo" && nix flake check --no-build >/dev/null 2>&1); then echo "FAIL: nix flake check --no-build failed"; return 1; fi
}

tests=(
  test_config_validates_with_zero_warnings
  test_stale_mango_user_template_entry_removed
  test_deprecated_capsule_border_role_migrated
  test_deprecated_capsule_group_fill_role_migrated
  test_stale_mango_template_copy_deleted
  test_custom_templates_intact
  test_default_nix_links_mango_conf_removed_only
  test_flake_check_passes
)
failed=0
for t in "${tests[@]}"; do
  if "$t"; then echo "PASS: $t"; else echo "FAIL: $t"; failed=$((failed + 1)); fi
done
if [ "$failed" -gt 0 ]; then
  echo "$failed unit test case(s) failed" >&2
  exit 1
fi
echo "noctalia config freshness: all checks passed"
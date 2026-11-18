#!/usr/bin/env bash
# Check that docs/overview.html renders and behaves, using the headless browser
# already on the system. Rerun it after changing the configuration: the page
# makes assumptions about the data (a package has a pname, a program module has
# settings) that a change upstream can break silently.
#
#   just overview-verify
set -euo pipefail

cd "$(dirname "$0")/../.."

page=$PWD/docs/overview.html
[ -f "$page" ] || {
  echo "docs/overview.html is missing; run 'just overview' first" >&2
  exit 1
}

chromium=$(command -v chromium || command -v chromium-browser || command -v google-chrome || true)
[ -n "$chromium" ] || {
  echo "no chromium on PATH, skipping the render check" >&2
  exit 0
}

expected_total=$(nix eval --json -f docs/overview/data.nix --apply 'd: d.total')
expected_local=$(nix eval --json -f docs/overview/data.nix --apply 'd: d.meta.localCount')

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The probe drives the real page inside iframes and prints one "key=value" line
# per assertion, so the pass/fail policy stays in the shell below.
cat >"$work/probe.html" <<HTML
<!doctype html><meta charset="utf-8"><body></body><script>
const page = "file://__PAGE__";
const frames = [];
const mk = (width, height) => {
  const f = document.createElement("iframe");
  f.style.cssText = "border:0;width:" + width + "px;height:" + height + "px";
  f.src = page;
  document.body.appendChild(f);
  frames.push(f);
  return f;
};
// An iframe is "complete" as about:blank before its own document arrives, so
// readiness means the card list the page renders is there.
const ready = (f) => new Promise((resolve) => {
  const started = Date.now();
  const poll = () => {
    const doc = f.contentDocument;
    if (doc && doc.querySelectorAll(".card").length > 0) return resolve();
    if (Date.now() - started > 15000) return resolve();
    setTimeout(poll, 50);
  };
  poll();
});

(async () => {
  const lines = [];
  try {
  const wide = mk(1440, 1600);
  const narrow = mk(760, 1400);
  await Promise.all(frames.map(ready));

  for (const pair of [[wide, "1440"], [narrow, "760"]]) {
    const f = pair[0];
    const label = pair[1];
    const doc = f.contentDocument;
    const win = f.contentWindow;
    lines.push("overflow." + label + "=" + (doc.documentElement.scrollWidth > win.innerWidth + 1 ? "yes" : "no"));
    lines.push("cards." + label + "=" + doc.querySelectorAll(".card").length);
    const icons = [...doc.querySelectorAll(".icon img")];
    lines.push("icons." + label + "=" + icons.length);
    lines.push("broken-icons." + label + "=" + icons.filter((i) => !i.complete || i.naturalWidth === 0).length);
    lines.push("sections." + label + "=" + doc.querySelectorAll(".section").length);
  }

  const doc = wide.contentDocument;
  const win = wide.contentWindow;
  const click = (el) => el.dispatchEvent(new win.MouseEvent("click", { bubbles: true }));
  const type = (value) => {
    const input = doc.getElementById("search");
    input.value = value;
    input.dispatchEvent(new win.Event("input", { bubbles: true }));
  };
  const navTo = (target) =>
    click([...doc.querySelectorAll(".nav-item")].find((b) => b.dataset.target === target));

  type("editor");
  const hits = doc.querySelectorAll(".card").length;
  lines.push("search.narrows=" + (hits > 0 && hits < 85 ? "yes" : "no"));
  type("zzzz-nothing-matches");
  lines.push("search.empty=" + (doc.querySelector(".empty") ? "yes" : "no"));
  type("");

  click(doc.getElementById("filter-local"));
  lines.push("local.cards=" + doc.querySelectorAll(".card").length);
  lines.push("local.only=" + ([...doc.querySelectorAll(".card")].every((c) => c.classList.contains("is-local")) ? "yes" : "no"));
  click(doc.getElementById("filter-all"));

  navTo("settings");
  lines.push("settings.panels=" + doc.querySelectorAll(".panel").length);
  lines.push("settings.rows=" + doc.querySelectorAll(".rows > div").length);
  // A query naming a program keeps that program's panel open. "jujutsu" is
  // specific to one panel, where "fish" also matches ghostty's command value
  // (the fish it launches) and so correctly keeps both.
  const panelsBefore = doc.querySelectorAll(".panel").length;
  type("jujutsu");
  const panelsAfter = doc.querySelectorAll(".panel").length;
  lines.push("settings.search.keeps-view=" + (panelsAfter === 1 && panelsBefore > 1 ? "yes" : "no"));
  type("zzzz-nothing-matches");
  lines.push("settings.search.empty=" + (doc.querySelector(".empty") ? "yes" : "no"));
  type("");

  navTo("overview");
  lines.push("back.cards=" + doc.querySelectorAll(".card").length);

  // Language switching: the page must be fully one language, not a mix. A
  // setting key that reached the screen verbatim would show up as an English
  // path in the Chinese view, so the label text is what gets checked.
  const switchTo = (code) => {
    const select = doc.getElementById("lang");
    select.value = code;
    select.dispatchEvent(new win.Event("change", { bubbles: true }));
  };
  lines.push("lang.options=" + [...doc.getElementById("lang").options].map((o) => o.value).join(","));
  for (const code of ["zh", "en"]) {
    switchTo(code);
    lines.push("lang." + code + ".html-lang=" + doc.documentElement.lang);
    lines.push("lang." + code + ".cards=" + doc.querySelectorAll(".card").length);
    lines.push("lang." + code + ".h1=" + doc.querySelector(".page-title").textContent);
    const labels = [...doc.querySelectorAll(".rows > div:nth-child(odd)")].map((el) => el.textContent);
    lines.push("lang." + code + ".raw-keys=" + labels.filter((l) => /^[a-z]+(\.[a-z-]+)+$/.test(l)).length);
    const untranslated = [...doc.querySelectorAll(".card-desc")].filter((el) => !el.textContent.trim()).length;
    lines.push("lang." + code + ".blank-descriptions=" + untranslated);
    navTo("settings");
    const settingsLabels = [...doc.querySelectorAll(".rows > div:nth-child(odd)")].map((el) => el.textContent);
    lines.push("lang." + code + ".settings-raw-keys=" + settingsLabels.filter((l) => /^[a-z]+(\.[a-z-]+)+$/.test(l)).length);
    navTo("overview");
  }

  // Translated descriptions have to be searchable, not just visible.
  switchTo("zh");
  type("文件管理器");
  const zhHits = [...doc.querySelectorAll(".card-name")].map((el) => el.textContent);
  lines.push("lang.zh.search-hits=" + zhHits.join(","));
  type("");
  switchTo("en");

  } catch (error) {
    lines.push("error=" + (error && error.message ? error.message : String(error)));
  }

  const pre = document.createElement("pre");
  pre.id = "probe-output";
  pre.textContent = lines.join("\n");
  document.body.appendChild(pre);
})();
</script>
HTML

sed -i "s|file://__PAGE__|file://$page|" "$work/probe.html"

result=$("$chromium" --headless --disable-gpu --no-sandbox --allow-file-access-from-files \
  --virtual-time-budget=8000 --dump-dom "file://$work/probe.html" 2>/dev/null |
  sed -n '/<pre id="probe-output">/,/<\/pre>/p' | sed 's/<[^>]*>//g' | sed '/^[[:space:]]*$/d')

[ -n "$result" ] || {
  echo "FAIL: the page produced no output; it did not run" >&2
  exit 1
}

echo "$result"

fail=0
check() {
  local got
  got=$(printf '%s\n' "$result" | sed -n "s/^$1=//p")
  if [ "$got" != "$2" ]; then
    echo "FAIL: $1 expected '$2', got '$got'" >&2
    fail=1
  fi
}

check overflow.1440 no
check overflow.760 no
check cards.1440 "$expected_total"
check cards.760 "$expected_total"
check broken-icons.1440 0
check broken-icons.760 0
check search.narrows yes
check search.empty yes
check local.cards "$expected_local"
check local.only yes
check settings.search.keeps-view yes
check settings.search.empty yes
check back.cards "$expected_total"
check lang.options en,zh
check lang.zh.html-lang zh
check lang.zh.cards "$expected_total"
check lang.zh.raw-keys 0
check lang.zh.settings-raw-keys 0
check lang.zh.blank-descriptions 0
check lang.zh.search-hits nautilus,yazi
check lang.en.html-lang en
check lang.en.cards "$expected_total"
check lang.en.raw-keys 0
check lang.en.settings-raw-keys 0
check lang.en.blank-descriptions 0

error_line=$(printf '%s\n' "$result" | sed -n 's/^error=//p')
if [ -n "$error_line" ]; then
  echo "FAIL: the probe threw: $error_line" >&2
  fail=1
fi

# One panel per program module plus the two summary panels. A module that stops
# exporting its settings would drop a panel without failing anything else.
panel_count=$(printf '%s\n' "$result" | sed -n 's/^settings.panels=//p')
if [ "$panel_count" -lt 9 ]; then
  echo "FAIL: settings.panels expected at least 9, got '$panel_count'" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "ok: docs/overview.html renders and behaves"

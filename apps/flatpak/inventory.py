#!/usr/bin/env python3
"""Flatpak inventory: capture / status / restore for atomic-workstation.

State is captured as one JSON file per machine profile:
    apps/flatpak/inventory/<profile>.json

Schema (v1):
    {
      "remotes": { "user": [...], "system": [...] },   # name, url, options
      "apps":    [ {application, origin, installation, branch, arch}, ... ]
    }

Everything is sorted, so re-running capture on an unchanged machine produces
a byte-identical file (no meaningless git diffs).

Restore is ADDITIVE by default: it adds missing remotes and installs missing
apps; it never uninstalls. --prune opts into removal of apps that are NOT in
the inventory, behind an interactive "yes" confirmation (--yes is ignored
for prune on purpose).

Exit codes: 0 success / skipped, 1 completed with errors, 2 fatal (bad usage).
"""

import argparse
import json
import os
import platform
import subprocess
import sys
from pathlib import Path

INVENTORY_VERSION = 1


def _tail(text, lines=3):
    """Last few lines of a possibly-None command output, as a plain string."""
    if not text:
        return ""
    kept = text.strip().splitlines()[-lines:]
    return " | ".join(kept)


def _run(argv, check=False, dry=False, quiet=False):
    """Run a command; return CompletedProcess. Never raises on rc != 0.

    A missing binary yields returncode 127 with a message in stderr instead
    of an unhandled FileNotFoundError — important on hosts where flatpak is
    simply not installed.
    """
    if dry:
        print("[dry-run] " + " ".join(argv), file=sys.stderr)
        return subprocess.CompletedProcess(argv, 0, "", "")
    try:
        proc = subprocess.run(argv, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        return subprocess.CompletedProcess(
            argv, 127, "", "command not found: " + (argv[0] if argv else "?")
        )
    if proc.stderr and not quiet:
        for line in _tail(proc.stderr).split(" | "):
            print(f"[flatpak] {line}", file=sys.stderr)
    if check and proc.returncode != 0:
        raise RuntimeError(_tail(proc.stderr) or "command failed: " + " ".join(argv))
    return proc


def _flatpak(args, check=False, dry=False):
    return _run(["flatpak"] + args, check=check, dry=dry)


def _have_flatpak():
    return _run(["flatpak", "--version"]).returncode == 0


APP_COLUMNS = ("application", "origin", "installation", "branch", "arch")
REMOTE_COLUMNS = ("name", "url", "options")


def _parse_tsv(text, columns):
    """Parse flatpak's TSV output into dicts; skips a header row if present."""
    rows = []
    for line in text.splitlines():
        if not line.strip():
            continue
        fields = line.split("\t")
        if len(fields) != len(columns):
            continue  # tolerate odd lines rather than crash
        rows.append(dict(zip(columns, fields, strict=True)))
    # Header detection: flatpak prints column names as the first row when
    # connected to a tty; drop it if present.
    if rows and all(str(rows[0].get(c, "")).strip().lower() == c for c in columns):
        rows = rows[1:]
    return rows


def _looks_like_runtime(app_id):
    suffixes = (".Platform", ".SDK", ".GL", ".VAAPI", ".ffmpeg", ".openh264")
    return any(app_id.endswith(s) for s in suffixes)

# Apps that duplicate something the image layer already owns. Recording one of
# these in the inventory would make restore.sh install the duplicate on a fresh
# machine, so capture leaves it out and says why (scripts/doctor.sh warns about
# the same app on the machine that has it). Keyed on the app id; flathub has
# shipped the Fcitx 5 app under more than one id, so every known id is listed.
CONFLICTS_WITH_IMAGE = {
    "org.fcitx.Fcitx5": (
        "sandboxed fcitx5 daemon: it races the image's host fcitx5 for the "
        "fcitx5 D-Bus name and keeps its rime data under ~/.var/app/"
    ),
    "bxx.esmrq.Wftim3": (
        "sandboxed fcitx5 daemon: it races the image's host fcitx5 for the "
        "fcitx5 D-Bus name and keeps its rime data under ~/.var/app/"
    ),
}


def _conflicts_with_image(app_id):
    """Reason this app must not enter the inventory, or None."""
    return CONFLICTS_WITH_IMAGE.get(app_id)


def _list_apps(installation):
    proc = _flatpak(
        ["list", "--app", "--columns=" + ",".join(APP_COLUMNS), "--" + installation],
        check=True,
    )
    rows = _parse_tsv(proc.stdout, APP_COLUMNS)
    # Defence in depth: --app already excludes runtimes; also drop anything
    # whose ref looks like a runtime (org.freedesktop.Platform and friends).
    kept = []
    for row in rows:
        app_id = row["application"]
        if _looks_like_runtime(app_id):
            continue
        conflict = _conflicts_with_image(app_id)
        if conflict:
            print(
                f"[flatpak] skipping {app_id} -- {conflict}\n"
                f"          remove it with: flatpak uninstall --{installation} -y {app_id}",
                file=sys.stderr,
            )
            continue
        kept.append(row)
    return kept


def _list_remotes(installation):
    proc = _flatpak(
        ["remotes", "--columns=" + ",".join(REMOTE_COLUMNS), "--" + installation],
        check=True,
    )
    return _parse_tsv(proc.stdout, REMOTE_COLUMNS)


def _scope_or_warn(fn, installation, what):
    """Run a per-scope query; a broken scope must not abort the whole capture.

    A machine can legitimately lack a system flatpak installation (or lack
    permission to read it); that is a warning, not a crash.
    """
    try:
        return fn(installation)
    except RuntimeError as exc:
        print(
            f"[WARN]  could not read {what} for the '{installation}' installation: {exc}",
            file=sys.stderr,
        )
        return []


def capture(profile, out_file):
    if not _have_flatpak():
        print(
            "[SKIP] flatpak is not installed on this machine — nothing to "
            "capture (expected on non-Bazzite hosts).",
            file=sys.stderr,
        )
        return 0

    inv = {
        "version": INVENTORY_VERSION,
        "profile": profile,
        "remotes": {
            "user": sorted(
                _scope_or_warn(_list_remotes, "user", "remotes"),
                key=lambda r: r["name"],
            ),
            "system": sorted(
                _scope_or_warn(_list_remotes, "system", "remotes"),
                key=lambda r: r["name"],
            ),
        },
        "apps": [],
    }

    apps = []
    for installation in ("user", "system"):
        for row in _scope_or_warn(_list_apps, installation, "apps"):
            row["installation"] = installation  # normalise (column echoes it)
            apps.append({k: row[k] for k in APP_COLUMNS})
    inv["apps"] = sorted(
        apps, key=lambda a: (a["application"], a["installation"], a["branch"])
    )

    out_path = Path(out_file)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = out_path.with_suffix(out_path.suffix + ".tmp")
    tmp.write_text(json.dumps(inv, indent=2, sort_keys=False, ensure_ascii=False) + "\n")
    os.replace(tmp, out_path)

    print(f"[OK]    flatpak inventory → {out_path} ({len(inv['apps'])} apps)", file=sys.stderr)
    return 0


def _load(path):
    """Load an inventory JSON; None if missing, ValueError if corrupt."""
    p = Path(path)
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"inventory file {path} is not valid JSON: {exc}") from exc


def status(profile, inv_file):
    if not _have_flatpak():
        print("[WARN]  flatpak is not installed here; nothing to compare.", file=sys.stderr)
        return 0
    try:
        inv = _load(inv_file)
    except ValueError as exc:
        print(f"[FAIL]  {exc}", file=sys.stderr)
        return 1
    if inv is None:
        print(
            f"[WARN]  no inventory file for profile '{profile}' ({inv_file}) — "
            "run capture first.",
            file=sys.stderr,
        )
        return 0

    installed = {}
    for installation in ("user", "system"):
        for row in _scope_or_warn(_list_apps, installation, "apps"):
            installed[(row["application"], installation, row["branch"])] = row

    wanted = {}
    for app in inv["apps"]:
        wanted[(app["application"], app["installation"], app["branch"])] = app

    missing = sorted(set(wanted) - set(installed))
    extra = sorted(set(installed) - set(wanted))

    if not missing and not extra:
        print(f"[OK]    flatpak matches the inventory ({len(wanted)} apps).", file=sys.stderr)
        return 0

    for key in missing:
        print(f"  missing on this machine: {key[0]} ({key[1]}, {key[2]})", file=sys.stderr)
    for key in extra:
        print(f"  installed but NOT in inventory: {key[0]} ({key[1]}, {key[2]})", file=sys.stderr)
    print(
        f"[INFO]  {len(missing)} missing, {len(extra)} extra — "
        "run 'restore' to install missing apps.",
        file=sys.stderr,
    )
    return 0


def restore(profile, inv_file, prune=False, dry=False, assume_yes=False):
    if not _have_flatpak():
        print("[FAIL] flatpak is not installed — cannot restore.", file=sys.stderr)
        return 2
    try:
        inv = _load(inv_file)
    except ValueError as exc:
        print(f"[FAIL]  {exc}", file=sys.stderr)
        return 2
    if inv is None:
        print(
            f"[FAIL] no inventory file for profile '{profile}' ({inv_file}) — "
            "capture first.",
            file=sys.stderr,
        )
        return 2

    errors = []

    current_remotes = {
        inst: {r["name"]: r for r in _scope_or_warn(_list_remotes, inst, "remotes")}
        for inst in ("user", "system")
    }
    inv_remotes = {
        inst: {r["name"]: r for r in inv["remotes"].get(inst, [])}
        for inst in ("user", "system")
    }
    needed_origins = {}
    for app in inv["apps"]:
        needed_origins.setdefault((app["installation"], app["origin"]), []).append(app)

    for (inst, origin), apps_needing in sorted(needed_origins.items()):
        if origin in current_remotes[inst]:
            continue
        meta = inv_remotes[inst].get(origin)
        if not meta or not meta.get("url"):
            errors.append(
                f"origin '{origin}' ({inst}) is missing on this machine and the "
                f"inventory has no URL for it; {len(apps_needing)} app(s) depend on it"
            )
            continue
        print(
            f"[INFO]  adding missing {inst} remote '{origin}' → {meta['url']}",
            file=sys.stderr,
        )
        proc = _flatpak(
            ["remote-add", "--if-not-exists", "--" + inst, origin, meta["url"]], dry=dry
        )
        if proc.returncode != 0:
            errors.append(
                f"could not add {inst} remote '{origin}': {_tail(proc.stderr) or '?'}"
            )
        else:
            current_remotes[inst][origin] = meta

    installed = set()
    for installation in ("user", "system"):
        for row in _scope_or_warn(_list_apps, installation, "apps"):
            installed.add((row["application"], installation, row["branch"]))

    native_arch = platform.machine()
    for app in inv["apps"]:
        key = (app["application"], app["installation"], app["branch"])
        if key in installed:
            continue
        # An inventory captured before a conflict rule existed (or edited by
        # hand) can still name an app the image already provides. Installing it
        # would reintroduce the duplicate on this machine — capture() refuses to
        # record these, this is the restore-side guard.
        conflict = _conflicts_with_image(app["application"])
        if conflict:
            print(
                f"[WARN]  inventory lists {app['application']}, which duplicates "
                f"an image component -- {conflict}\n"
                f"        skipping it; re-run capture to drop it from the inventory",
                file=sys.stderr,
            )
            continue
        ref = app["application"]
        if app.get("arch") and app["arch"] not in ("", native_arch):
            ref += "/" + app["arch"]
        ref += "//" + app["branch"]
        origin = app["origin"]
        if origin not in current_remotes[app["installation"]]:
            continue  # already reported above
        print(
            f"[INFO]  installing {app['installation']} {app['application']} "
            f"({app['branch']})",
            file=sys.stderr,
        )
        proc = _flatpak(
            [
                "install",
                "--" + app["installation"],
                "--assumeyes",
                "--noninteractive",
                origin,
                ref,
            ],
            dry=dry,
        )
        if proc.returncode != 0:
            errors.append(
                f"failed to install {ref} from '{origin}' "
                f"({app['installation']}): {_tail(proc.stderr) or '?'}"
            )
        else:
            installed.add(key)

    if prune:
        extra = sorted(
            installed
            - {(a["application"], a["installation"], a["branch"]) for a in inv["apps"]}
        )
        if not extra:
            print("[OK]    nothing to prune — no extra flatpaks installed.", file=sys.stderr)
        else:
            print(
                f"\nThe following {len(extra)} app(s) are installed but NOT in the "
                "inventory:",
                file=sys.stderr,
            )
            for key in extra:
                print(f"  - {key[0]}  ({key[1]}, branch {key[2]})", file=sys.stderr)
            if dry:
                print("[dry-run] prune would uninstall the apps above.", file=sys.stderr)
            elif assume_yes:
                print(
                    "[FAIL] --yes is deliberately ignored for --prune: removal needs "
                    "an interactive 'yes'.",
                    file=sys.stderr,
                )
                errors.append("prune refused (non-interactive)")
            else:
                answer = input("\nType 'yes' to UNINSTALL them, anything else to abort: ")
                if answer.strip() == "yes":
                    for app_id, inst, branch in extra:
                        print(f"[INFO]  uninstalling {app_id} ({inst})", file=sys.stderr)
                        proc = _flatpak(
                            [
                                "uninstall",
                                "--" + inst,
                                "--assumeyes",
                                app_id + "//" + branch,
                            ]
                        )
                        if proc.returncode != 0:
                            errors.append(f"failed to uninstall {app_id}")
                else:
                    print("[INFO]  prune aborted — nothing uninstalled.", file=sys.stderr)

    if errors:
        print(f"\n[FAIL] restore completed with {len(errors)} error(s):", file=sys.stderr)
        for e in errors:
            print("  - " + e, file=sys.stderr)
        return 1
    print(f"[OK]    flatpak restore complete (profile '{profile}').", file=sys.stderr)
    return 0


def main(argv=None):
    doc = (__doc__ or "Flatpak inventory for atomic-workstation.").strip()
    parser = argparse.ArgumentParser(description=doc.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_cap = sub.add_parser("capture", help="scan this machine and write the inventory JSON")
    p_cap.add_argument("--profile", required=True)
    p_cap.add_argument("--out", required=True)

    p_stat = sub.add_parser("status", help="diff installed apps vs the inventory")
    p_stat.add_argument("--profile", required=True)
    p_stat.add_argument("--file", required=True)

    p_res = sub.add_parser("restore", help="add missing remotes/apps from the inventory")
    p_res.add_argument("--profile", required=True)
    p_res.add_argument("--file", required=True)
    p_res.add_argument(
        "--prune",
        action="store_true",
        help="ALSO uninstall apps not in the inventory (interactive confirm)",
    )
    p_res.add_argument("--dry-run", action="store_true")
    p_res.add_argument(
        "--yes",
        action="store_true",
        help="skip confirmations (ignored for --prune on purpose)",
    )

    args = parser.parse_args(argv)

    if args.cmd == "capture":
        return capture(args.profile, args.out)
    if args.cmd == "status":
        return status(args.profile, args.file)
    if args.cmd == "restore":
        return restore(
            args.profile,
            args.file,
            prune=args.prune,
            dry=args.dry_run,
            assume_yes=args.yes,
        )
    return 2


if __name__ == "__main__":
    sys.exit(main())

# Agent Instructions

## Repository Layout

- `flake.nix` — single source of truth for inputs, `nixpkgsConfig`, overlays, shared `sccache` settings, `packages`, `legacyPackages`, `nixosConfigurations`, `checks`, and `formatter`.
- `overlay.nix` — auto-discovers every `pkgs/*.nix` file and injects `repoRoot`, `craneLib`, or `buildMyGoApp` when a package's function signature asks for them.
- `lib/` — shared pure Nix helpers and builders (`lib/fonts.nix`, `lib/build-mygo-app.nix`).
- `pkgs/` — local derivations and their in-tree sources (`pkgs/overview/`, `pkgs/fcitx5-hymt-translate/`, `pkgs/nsh-launcher.sh`, `pkgs/pig-swarm.sh`).
- `system/` — NixOS system modules wired through `system/init.nix`.
- `home/` — Home Manager modules wired through `home/init.nix` (provides `_module.args.liveFiles` for out-of-store editable desktop configs).
- `scripts/` — repository maintenance scripts (`lib.sh`, `bump-packages.sh`, `scaffold-package.sh`).

## Common Commands

```bash
just check         # Format check, shellcheck, package invariants, overview tests, NixOS eval
just fmt           # Format Nix files with nixfmt-tree
just build         # Build the NixOS system configuration
just switch        # Build and activate the NixOS system configuration
just bump [pkg...] # Update pkgs/ derivations that declare passthru.bump
just snapshot      # Refresh pkgs/overview/snapshot.json from pkgs/overview/data.nix
just memo-verify   # End-to-end check for memo commands (requires live model gateway)
```

## Version Control & Commit Policy

This repository uses **jj** (`jujutsu`), not bare `git`.

- **Commit directly on completion**: After finishing a task and running `just check` (plus relevant builds), commit changes directly with `jj commit -m "<message>"` without asking for confirmation unless the user explicitly says not to commit.
- **Do not push automatically**: Only run `jj git push` or `bd dolt push` when explicitly requested.
- **Commit style**: Follow Conventional Commits (`feat(scope): ...`, `fix(scope): ...`, `refactor(scope): ...`, `chore(scope): ...`, `docs(scope): ...`), and keep changes of different natures in separate commits.

## Non-Interactive Shell Commands

Always pass non-interactive flags for file and remote commands (`cp -f`, `mv -f`, `rm -f`, `rm -rf`, `ssh -o BatchMode=yes`, `scp -o BatchMode=yes`) so shell aliases never hang waiting on confirmation prompts.

## Configuration Minimalism

Keep NixOS, Home Manager, and package configurations minimal:

- Do not duplicate defaults, environment variables, wrappers, or runtime workarounds already handled by upstream packages or modules.
- When switching to an upstream flake or package, delete local workarounds, activation scripts, and overrides that are no longer needed.
- Encode recurring repository rules in `flake.nix` `checks` instead of prose whenever possible.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:46cd31e7 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Repository default (auto-commit)**: This repository explicitly authorizes direct local commits upon task completion. Close finished beads, run quality gates, and run `jj commit -m "..."` without waiting for confirmation (unless the current user request says "do not commit"). Do not push (`jj git push` / `bd dolt push`) unless explicitly asked.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Commit local changes**:
   ```bash
   jj status
   jj commit -m "<type>(<scope>): <summary>"

   # Only when explicitly requested by the user:
   # bd dolt push
   # jj git push
   ```
5. **Hand off** - Summarize changes, commit, validation, and issue status

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Commit completed work locally with `jj commit` directly without asking for confirmation (unless the current user request forbids it). Do not push without an explicit request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->

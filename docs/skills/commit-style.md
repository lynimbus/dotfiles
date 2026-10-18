---
name: commit-style
description: Write, review, lint or bulk-rewrite git/jj commit messages against Conventional Commits 1.0.0. Use when creating a commit, when asked to standardize or clean up commit history, when commit messages need translating or reformatting, or when setting up commit-msg validation in a repository.
license: MIT
---

# Commit messages: Conventional Commits 1.0.0

Every rule below traces to the [Conventional Commits 1.0.0 specification](https://www.conventionalcommits.org/en/v1.0.0/), or to [@commitlint/config-conventional](https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional), the de-facto machine-checkable profile. When a project states its own rule, the project wins; otherwise this is the default.

## Format

```
<type>[(<scope>)][!]: <description>

[body]

[footer(s)]
```

The header is mandatory and single-line. One space after the colon, none before it. The body and each footer are preceded by exactly one blank line, and both are optional. Default to the header alone — add a body only when the reason or the blast radius cannot fit in one line. Plain text, no Markdown headings or bullet lists.

## Types

`feat`, `fix`, `build`, `chore`, `ci`, `docs`, `perf`, `refactor`, `revert`, `style`, `test` — lowercase.

`feat` and `fix` carry SemVer meaning (MINOR, PATCH) and must be used accordingly: a new capability is `feat`, a defect repair is `fix`. Everything else is neutral. If no listed type fits, the change usually wants splitting into several commits.

| type | for |
| --- | --- |
| `feat` | new capability or behavior |
| `fix` | defect repair |
| `build` | build system, packaging, dependency versions |
| `chore` | upgrades, lockfiles, cleanup, repo plumbing |
| `ci` | pipelines and automation |
| `docs` | documentation and comments |
| `perf` | speed without behavior change |
| `refactor` | restructuring without behavior change |
| `revert` | undo a commit; add `Refs:` footer with the SHAs |
| `style` | formatting, whitespace, naming only |
| `test` | tests and fixtures |

## Scope

Optional, and omission is the right default: if the type already says everything, add no scope.

When used, four constraints:

1. Lowercase noun, matching `[a-z0-9.+-]`; use `-`, never spaces or underscores.
2. Names a section of the codebase — a directory or module — not a person, an issue number, or a feeling.
3. One vocabulary per repository. A synonym pair (`pkgs`/`packages`, `nvim`/`neovim`) is a defect; converge on one and rename the rest.
4. One scope per commit. Spans several sections → drop the scope or split the commit.

A product name is not a scope (`feat(obs-studio)` is wrong; `feat(pkgs)` is right when the change is packaging). Initial vocabularies look like `build system home desktop pkgs ci docs`; adapt to the real tree, then freeze it.

## Description

- Imperative, describing what the commit does — not "I changed X" and not "X is now Y".
- ≤100 characters (the commitlint header limit). Aim for ≤60 so `git log --oneline` and jj's default view never wrap.
- No trailing period (neither `.` nor `。`), no emoji.
- One language per repository. If the description is Chinese, `type` and `scope` stay lowercase English, otherwise tooling cannot parse them.
- Specific beats vague: "fix fcitx5 input in QQ under niri", not "fix input method issue".

## Breaking changes

Mark with `!` after the type or scope, a `BREAKING CHANGE:` footer, or both:

```
feat(api)!: drop the v1 endpoint

BREAKING CHANGE: callers must migrate to /v2; v1 is gone
```

When `!` is used, the description itself must name what breaks — "adjust the interface" is not a description.

## Footers

Git-trailer style: `Token: value`, with `-` replacing spaces in the token.

```
Refs: #123
Reviewed-by: Z
BREAKING CHANGE: the extends key now extends other config files
```

`BREAKING CHANGE` must be uppercase (`BREAKING-CHANGE` is equivalent); other tokens are case-insensitive.

## Rewriting an existing history

Bulk renaming commit messages rewrites commit hashes, and those hashes propagate to every clone and downstream branch. Establish before starting:

- **Which commits** are actually in scope. In git: `git log --oneline <branch>`. In jj: `jj log -r '::main'` — this excludes commits reachable only from backup or parked remote bookmarks. Confirm with the user which set they mean; a full `jj log` often includes unrelated parked history.
- **Whether the repository is already pushed.** If it is, the push becomes a force-push and every collaborator must re-clone or reset.
- **What cannot be changed.** The jj root commit (`zzzzzzzzzzzz`, no parents) is immutable — `jj describe` fails on it. Empty placeholder commits with real trees can usually be renamed from their diff.
- **What counts as garbage.** Messages like `tmp`, `clean`, `rebase`, `wip`, `first commit`, or jokes should be renamed from the actual diff, not preserved. Read the diff before naming.

Procedure in jj: collect `change_id` → new message pairs, validate every one against the rules, then `jj describe -r <change_id> -m <message>` per commit. Verify afterwards that content is unchanged — compare trees, not `jj diff -r A -r B`, which can report spurious differences:

```sh
git diff --quiet <old-sha> <new-sha> && echo "identical content"
jj diff --from <old-rev> --to <new-rev> --stat   # 0 files changed
```

In git, use `git rebase -i --root` with `reword`, or `git filter-repo --message-callback`.

Do not invent a diff for a commit: read `jj diff -r <rev>` / `git show <sha>` first, then name it. A message that describes what the diff does not do is worse than a vague one.

## Validation

Check each message mechanically before it lands. Minimal POSIX-ish rules, no dependencies:

- header matches `^(feat|fix|build|chore|ci|docs|perf|refactor|revert|style|test)(\([a-z0-9.+-]+\))?!?: .+$`
- header length ≤100 characters — count characters, not bytes, or CJK text measures three times too long
- description does not end with `.` or `。`
- when a body exists, line 2 is blank

Hook it up as `commit-msg` (git) or a CI/pre-push step. In jj, `jj describe` bypasses git hooks entirely, so a lint command run in CI or by hand is the only reliable gate.

Judge by review, not by linter: imperative mood, specificity, whether the scope names a section rather than a product, and whether the message matches the diff.

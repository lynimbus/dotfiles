# Matt Pocock Skills Research

## Scope

This note reviews the skills published in the author's official repository and the corresponding AI Hero pages. Recommendations are based on the documented workflow, not on popularity claims.

## Installed

- `grill-me` is a user-invoked, stateless interview for turning a loose idea into explicit decisions. It works outside a code repository and runs in rounds over the current decision frontier. Source: [AI Hero page](https://www.aihero.dev/skills-grill-me), [skill source](https://github.com/mattpocock/skills/blob/main/skills/productivity/grill-me/SKILL.md).
- `grill-me` delegates the actual interview to the `grilling` skill, so both `skills/productivity/grill-me` and `skills/productivity/grilling` are enabled in Pi. Source: [grill-me source](https://github.com/mattpocock/skills/blob/main/skills/productivity/grill-me/SKILL.md), [grilling source](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md).
- `grill-with-docs`, `diagnosing-bugs`, `tdd`, `codebase-design`, and the `domain-modeling` dependency are enabled. The existing `pi-review` package is retained instead of enabling the author's separate `code-review` skill. Source: [engineering index](https://github.com/mattpocock/skills/blob/main/skills/engineering/README.md), [skill sources](https://github.com/mattpocock/skills/tree/main/skills/engineering).

## Recommendations

### 1. `grill-with-docs`

Best next addition for substantial changes to this configuration repository. It combines the grilling flow with domain-modeling and records the resulting terminology and decisions in `CONTEXT.md` and ADRs. Use it when a change has design choices that should survive the current conversation; keep using `grill-me` for ideas that should leave no files behind. Source: [engineering index](https://github.com/mattpocock/skills/blob/main/skills/engineering/README.md), [skill source](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md).

Caveat: it is stateful and writes repository documentation, so it should be installed only if that workflow is wanted here.

### 2. `code-review`

High value before committing non-trivial changes. It separates review into a Standards axis and a Spec axis, then runs the two reviews in parallel. Source: [engineering index](https://github.com/mattpocock/skills/blob/main/skills/engineering/README.md), [skill source](https://github.com/mattpocock/skills/blob/main/skills/engineering/code-review/SKILL.md).

Caveat: the skill expects a fixed comparison point and an issue-tracker document at `docs/agents/issue-tracker.md`; the repository would need that setup before the full workflow is useful.

### 3. `diagnosing-bugs`

Worth adding for hard failures and performance regressions. Its defining rule is to build and run a tight, red-capable feedback loop before ranking hypotheses, then finish with a regression test and cleanup. Source: [engineering index](https://github.com/mattpocock/skills/blob/main/skills/engineering/README.md), [skill source](https://github.com/mattpocock/skills/blob/main/skills/engineering/diagnosing-bugs/SKILL.md).

### 4. `tdd`

Useful when this repository grows executable logic or when fixing a bug in a project with tests. It emphasizes testing public interfaces at agreed seams, then working one red-green vertical slice at a time. Source: [engineering index](https://github.com/mattpocock/skills/blob/main/skills/engineering/README.md), [skill source](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/SKILL.md).

### 5. `codebase-design`

A useful supporting reference rather than a standalone workflow. It gives precise vocabulary for modules, interfaces, depth, seams, adapters, leverage, and locality; the author positions it as a dependency for design and testability work. Source: [engineering index](https://github.com/mattpocock/skills/blob/main/skills/engineering/README.md), [skill source](https://github.com/mattpocock/skills/blob/main/skills/engineering/codebase-design/SKILL.md).

## Suggested order

1. Use `grill-with-docs` when persistent project vocabulary and ADRs are welcome.
2. Use `diagnosing-bugs` and `tdd` when the corresponding work appears regularly.
3. Treat `codebase-design` as a supporting skill pulled in by design-heavy workflows.
4. Use the existing `pi-review` package for review work instead of adding the separate `code-review` skill.

The author's repository distinguishes user-invoked skills from model-invoked skills. It is therefore better to add a small, intentional subset than to enable the whole repository. Source: [repository README](https://github.com/mattpocock/skills/blob/main/README.md).

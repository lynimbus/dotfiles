---
name: adversarial-code-review
description: "Adversarial code review — deliberately attack the change to catch the bugs LLMs still produce: system design flaws, UI usability problems, and missing broader context. Use when reviewing code, after implementing a feature or fix, or before declaring work done."
---

# Adversarial Code Review

LLMs still produce bugs, but those bugs are different than what they used to be — less off-by-ones, more about system design, UI usability, and missing broader context. Some kinds of coding have been solved; not all. Adversarial code review is an incredibly powerful tool for catching the remaining kinds: assume the change is broken, then try to prove it.

## The one-line prompt

> Use a dynamic workflow to adversarial test every edge case.

Scope it to what you're building: "...every edge case in an iOS simulator", "...in the running app", "...in the browser", "...in the test harness".

## Core principle

Review as an adversary, not a rubber-stamper. **Dynamic beats static** — actually run the code and exercise it, don't just read it and reason. A dynamic workflow surfaces the failures that reading misses.

## What to attack

Models still fail on three axes. Attack all three:

1. **System design** — does the change fit the architecture it lands in? State management, failure handling, concurrency, module boundaries, how the pieces compose. Off-by-ones are solved; wrong seams are not.

2. **UI usability** — can a real user actually use this? Walk the flows like a user: empty states, error states, partial data, long names, slow networks, destructive actions, keyboard/accessibility paths. What looks fine in a happy-path demo but breaks in real use?

3. **Missing broader context** — what does this change assume about the rest of the system? Who else calls these functions, what contracts leak, what happens in production (scale, real data, other features, older clients) that the local happy path never shows?

## Process — the dynamic workflow

1. **Locate the seams** — read the change and the interfaces it crosses; note every input, state transition, and integration point.
2. **Enumerate edge cases** — per seam: inputs, states, errors, concurrency, ordering, integration with adjacent modules.
3. **Attack dynamically** — run each case: simulator, browser, test harness, REPL, or the running app. Reproduce, don't speculate. If it can't be run, walk it with concrete data in hand.
4. **Report** — findings with reproduction steps and the fix; for a clean bill of health, say exactly what you attacked.

## Intensity levels

Scale the depth like Claude's `/code-review`:

- **low** — quick adversarial pass: obvious design, usability, and context bugs.
- **medium** — walk the flows and edge cases, run the code, verify fixes.
- **high** — exhaustive: every seam, every edge case, dynamic adversarial simulation, prioritized findings.

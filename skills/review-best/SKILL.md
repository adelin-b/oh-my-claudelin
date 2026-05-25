---
name: review-best
description: "Route code review to the right tool: built-in /review for PRs on GitHub, omc:code-reviewer for deep local pre-commit review, omc:verifier for the completion-claim gate, omc:critic for plan/spec reviews. Use whenever the user asks to review, audit, or sign off on code, a diff, a PR, or a plan."
category: decision-layer
tags: [review, quality, verification]
keywords: [review, audit, code-review, pr-review, lint]
sources: []
composed_from:
  - omc:code-reviewer
  - omc:verifier
  - omc:critic
  - builtin:/review
compose_rule: |
  Pick by the artifact being reviewed and the stage.

  Decision tree:
    1. PR open on GitHub, want inline comments posted there?
       → built-in `/review --comment` (or `/review` for local report).
         Effort flag: --low / --medium / --high. Default medium.

    2. Local diff before commit, want a deep human-style review with reasoning?
       → omc:code-reviewer (model=opus). Severity-rated, SOLID/perf/style/logic.

    3. About to claim "done" / "fixed" / "complete"?
       → omc:verifier. Iron law: no completion claims without fresh evidence
         (test pass, build clean, behavior reproduced).

    4. Reviewing a PLAN, spec, or design doc (not code)?
       → omc:critic. Structured multi-perspective critique.

    5. Caveman mode is active and a terse line-per-finding output is wanted?
       → caveman:cavecrew-reviewer.

  Stage stacking (use multiple, in order):
    plan critique → critic
    pre-commit    → omc:code-reviewer
    PR open       → /review --comment
    pre-merge     → omc:verifier (gate)

  NEVER use:
    - pr-review-toolkit (removed — OMC covers).
    - feature-dev:code-reviewer (removed — OMC covers).
    - code-review@claude-plugins-official (removed — duplicate of built-in /review).

compose_variants:
  - id: stage-routed
    summary: "Each lifecycle stage routes to a single reviewer (plan→critic, local→code-reviewer, PR→/review, completion→verifier)."
    weakest_link: "Requires the agent to know the stage; stage misclassification routes to a wrong tool."
  - id: omc-only
    summary: "Pipe everything through omc:code-reviewer regardless of stage."
    weakest_link: "Loses GH PR inline-comment integration entirely; verifier gate skipped."
  - id: builtin-only
    summary: "Only use built-in /review; skip OMC review agents."
    weakest_link: "Loses deep reasoning for local pre-commit; no completion-claim gate."

selected: stage-routed
selection_rationale: |
  Each tool is best at exactly one stage. omc-only loses GH integration and skips the
  verifier gate (a documented OMC iron law). builtin-only is too thin for deep local
  review. stage-routed's weak link (classification) is mechanical and easy: the agent
  can name the stage in one sentence before picking.

weakest_link: "If the agent does code-reviewer + /review on the same diff, the reports overlap; pick one per stage, not both."

last_synced: 2026-05-26T00:00:00Z
upstream_hash: ~
---

# review-best

## Stage → tool

| Stage | Tool | Invocation |
|---|---|---|
| Plan / spec | omc:critic | Spawn via Task tool, model=opus |
| Local diff (pre-commit) | omc:code-reviewer | Spawn via Task tool, model=opus |
| GH PR (post comments) | built-in `/review` | `/review --comment` (or with `--high` for thorough) |
| Completion claim | omc:verifier | Spawn before saying "done" |
| Caveman terse review | caveman:cavecrew-reviewer | Spawn via Task tool |

## Effort levels for `/review`

- `--low` / `--medium` (default): fewer, high-confidence findings.
- `--high` / `--max`: broader coverage, may include uncertain findings.

## What NOT to do

- Don't run code-reviewer AND `/review` on the same diff — pick one per stage.
- Don't skip the verifier gate before claiming completion.
- Don't reach for the removed plugins (`pr-review-toolkit`, `feature-dev:code-reviewer`, `code-review@official`).

## Drift signals

- OMC release tag (code-reviewer, verifier, critic ship with OMC)
- Claude Code built-in `/review` skill version

---
name: memory-best
description: "Route memory writes/reads to the right layer: auto-memory for cross-session user/project facts, ctx-mode for per-session sandbox, omc:wiki for project-scoped compounding knowledge, mex for structured agent scaffold + drift. Use whenever the user says remember/forget/note/recall, or when the agent needs to persist a fact, decision, or pattern."
category: decision-layer
tags: [memory, state, persistence, knowledge]
keywords: [remember, recall, note, memory, wiki, scaffold]
sources: []
composed_from:
  - auto-memory
  - ctx-mode
  - omc:wiki
  - mex-agent
compose_rule: |
  Memory routes by LIFETIME and SCOPE. Pick the layer whose lifetime+scope matches the fact.

  Decision tree:
    1. Fact about the USER (preferences, role, identity, ongoing projects, feedback)?
       → auto-memory at ~/.claude/projects/<proj>/memory/.
         Write a typed memory file (user|feedback|project|reference) + add a one-line entry
         to MEMORY.md. Loaded into context at every session start automatically.

    2. Intermediate capture / large output that should NOT pollute conversation context
       for THIS session only?
       → ctx-mode. Use `ctx_batch_execute` to run + index, then `ctx_search` to query.
         `ctx_execute` for derived processing. Bytes stay in the sandbox.

    3. Knowledge ABOUT THE PROJECT (architecture decisions, gotchas, runbooks, why-we-did-it)
       that should compound across sessions, scoped to this repo?
       → omc:wiki. Markdown pages that accrete. Karpathy-style.

    4. Structured AGENT MEMORY SCAFFOLD (AGENTS.md, ROUTER.md, context/, patterns/) for a
       repo, with drift detection so the scaffold stays honest?
       → mex (`mex-agent`). `npx mex-agent setup` once; `mex check` for drift score;
         `mex sync` to fix.

    5. Inside an active OMC team run, share state BETWEEN agents in the same session?
       → OMC shared_memory / project_memory tools.

  NEVER use:
    - graphiti-memory (removed — heavy infra, low usage).
    - graphify (removed — duplicate of graphiti).
    - ragflow globally (now project-scoped to better-chatvote only).

  Truth source by question type:
    "Who is the user / what do they want?"           → auto-memory
    "What is THIS conversation doing?"                → ctx-mode session memory
    "How is THIS project organized / why?"            → mex scaffold > omc:wiki > AGENTS.md
    "What did we decide in past project sessions?"    → omc:wiki

  Synergy:
    - mex `ROUTER.md` can link out to omc:wiki pages for deep dives.
    - auto-memory project entries can reference mex `context/*` paths.
    - ctx-mode timeline auto-captures decisions; promote them to wiki/mex when they stabilize.

compose_variants:
  - id: layered-by-lifetime
    summary: "Each layer owns one lifetime: session (ctx) → project (wiki/mex) → cross-project (auto-memory). Clear separation."
    weakest_link: "User facts that emerge inside a project session need to be promoted upward by hand."
  - id: scaffold-first
    summary: "mex scaffold is canonical for everything project-related; wiki/ctx feed into it."
    weakest_link: "Locks into mex's structure; harder to share knowledge across projects without scaffold."
  - id: user-first
    summary: "auto-memory is the apex; everything else is ephemeral."
    weakest_link: "Loses project-scoped detail that doesn't belong to user identity."

selected: layered-by-lifetime
selection_rationale: |
  Each layer already has a natural lifetime that maps cleanly to a question type. Forcing
  one layer to cover all (scaffold-first or user-first) creates a single point of decay
  and inflates the canonical memory file. The promotion friction in layered-by-lifetime
  is recoverable — the agent can lift a fact upward in one step — and worth the clean
  separation it buys.

weakest_link: "When a fact straddles two layers (e.g., user preference learned inside a project context), the agent must explicitly write to both or pick the higher-lifetime layer."

last_synced: 2026-05-26T00:00:00Z
upstream_hash: ~
---

# memory-best

## Quick map

| Question | Layer | Where |
|---|---|---|
| Who is the user? | auto-memory | `~/.claude/projects/<proj>/memory/MEMORY.md` |
| What's the current session doing? | ctx-mode | `ctx_search(sort:"timeline")` |
| How is this project structured / why? | mex > wiki | `AGENTS.md`, `.mex/`, `<proj>/.claude/wiki/` |
| What did we decide last week on this repo? | omc:wiki | `<proj>/.claude/wiki/` |
| Cross-agent shared state in this team run? | OMC shared_memory | MCP tool |

## Concrete operations

### auto-memory write

Create `~/.claude/projects/-Users-<user>/memory/<topic>.md`:

```yaml
---
name: <kebab-slug>
description: <one-line summary>
metadata:
  type: user|feedback|project|reference
---

<body — for feedback/project, structure as rule + **Why:** + **How to apply:**>
```

Add a one-line entry to `MEMORY.md` under its section.

### ctx-mode query

Resume work / search prior decisions:

```
mcp__plugin_context-mode_context-mode__ctx_search(queries: ["...", "..."], sort: "timeline")
```

### omc:wiki

Invoke `/oh-my-claudecode:wiki` or use the wiki_* MCP tools. Pages live under the project's wiki dir.

### mex

```bash
npx mex-agent setup    # one-time per project
mex check              # drift score
mex sync               # fix drift
mex log "decision: ..." # append to .mex/events/decisions.jsonl
```

## What NOT to do

- Do not write user identity facts to omc:wiki (lifetime mismatch).
- Do not write session-only intermediate dumps to auto-memory (would pollute every future session).
- Do not invoke graphiti-memory or graphify (removed).
- Do not enable ragflow globally (project-scoped now).

## Drift signals

- `npm view mex-agent version`
- ctx-mode plugin release tag
- OMC release tag (omc:wiki ships with OMC)
- auto-memory MEMORY.md line count (sanity check; warn if >180)

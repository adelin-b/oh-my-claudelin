---
name: add-tool
description: "Integrate a new tool (skill, MCP, plugin, CLI, or AI-harness component) into the existing stack. Researches the tool via opensrc + plugin:context7 + skill-x audit + WebFetch fallback, classifies it under a FEATURE-MAP domain, surfaces overlap with installed tools, and writes back to FEATURE-MAP.md + sync.config.json + the affected *-best composed SKILL.md. Use whenever the user says add tool / integrate / install / wire up / onboard / how do I use X / where does Y go."
category: decision-layer
tags: [integration, onboarding, audit, drift]
keywords: [add, integrate, install, wire, onboard, new-tool, new-mcp, new-skill, new-plugin]
sources: []
composed_from:
  - skill-x:audit
  - opensrc
  - plugin:context7
  - builtin:WebFetch
  - oh-my-claudelin:FEATURE-MAP
compose_rule: |
  Add-tool is the executable form of docs/ADD-A-TOOL.md. It enforces the
  same discipline at runtime so a new tool cannot land untracked.

  Phases (run in order, each phase blocks until prior is complete):

  Phase 1 — IDENTIFY
    Required input: tool name + (optional) package URL / GitHub repo / MCP id.
    If only a name is given, search via:
      a. opensrc path <name>          # if it's an npm/PyPI/crates pkg, get the cache path
      b. plugin:context7 resolve-library-id <name>   # docs lookup
      c. gh search repos <name>       # GitHub fallback
      d. WebFetch / WebSearch         # last resort
    Classify into ONE FEATURE-MAP domain (browser, memory, review, docs,
    planning, execution, search, git, test, skill-mgmt, security, design,
    data, external-service, fix-skill).

  Phase 2 — RESEARCH
    Read the actual source / docs:
      - rg "function|class|export" "$(opensrc path <pkg>)"  # if installed
      - plugin:context7 query-docs <lib-id> "<task>"        # API shape
      - read README.md from GitHub if no opensrc cache
    Capture: install method, version, primary CLI/API surface, version
    probe command (npm view / gh release / etc), homepage URL.

  Phase 3 — AUDIT OVERLAP
    Read ~/Developer/oh-my-claudelin/FEATURE-MAP.md for the chosen domain.
    Grep tool roles for similar phrases. Run:
      (cd ~/Developer/skill-x && \
       SKILL_X_SKILLS_DIR=$HOME/Developer/oh-my-claudelin/skills \
       node tools/audit.mjs)
    Classify the new tool against existing rows:
      - NO OVERLAP        → standalone, add map row only
      - OVERLAPS 1 tool   → add to that *-best composed_from + extend decision tree
      - OVERLAPS N tools  → create new *-best/SKILL.md if none exists for this domain
      - PURE DUPLICATE    → either reject the new tool or mark the older one ❌

  Phase 4 — WRITE BACK (atomic — all in one commit)
    a. FEATURE-MAP.md: append row under the domain table with name / type /
       status / one-line role. Update decision rule if overlap changed it.
    b. sync.config.json: add parents.<tool-id> with kind, cmd, args (use
       structured cmd+args, NOT shell string — see existing entries).
       Allowed cmd values: npm, gh, node, claude.
    c. If composed: edit the affected skills/<domain>-best/SKILL.md:
         - composed_from: append parent id
         - compose_rule: add numbered branch in decision tree
         - compose_variants: if a new variant emerges
         - selected / selection_rationale: only if the winner changes
         - last_synced: bump
         - upstream_hash: set to ~ (next sync-parents recomputes)

  Phase 5 — VERIFY
    a. bash ~/Developer/oh-my-claudelin/scripts/doctor.sh  → must be 11/11 ok
    b. node ~/Developer/oh-my-claudelin/scripts/sync-parents.mjs  → confirm
       the new parent resolves to a hash
    c. Re-run install.sh if a new *-best skill was added (links it).

  Phase 6 — COMMIT
    git add FEATURE-MAP.md sync.config.json skills/<affected>/SKILL.md
    git commit -m "feat(<domain>): add <tool-name> to the routing"
    git push

  HARD RULES:
    - Never edit FEATURE-MAP.md without also editing sync.config.json (drift
      detection breaks otherwise).
    - Never add a tool's name to composed_from without also adding it to
      sync.config.json (compose_rule will reference an untracked parent).
    - Never silently mark a tool ❌ — always one-line reason in FEATURE-MAP.
    - Never invoke this skill without producing exactly one git commit.

compose_variants:
  - id: research-first
    summary: "Research the tool exhaustively (opensrc + context7 + GH) before touching FEATURE-MAP."
    weakest_link: "Slow on simple obvious tools — overkill for a one-line CLI."
  - id: classify-first
    summary: "Ask the user the domain + overlap classification up front; research only what's needed to fill the map row."
    weakest_link: "Depends on user judgment about overlap — they may miss conflicts you'd catch."
  - id: phased-block
    summary: "Strict 6-phase pipeline above. Each phase blocks until prior complete. Atomic commit at end."
    weakest_link: "Rigid — for trivial tools (a one-bug-fix skill with no overlap) the phases are heavy."

selected: phased-block
selection_rationale: |
  research-first wastes time on obvious tools.
  classify-first leaks classification work to the user — defeats the point
  of automation.
  phased-block has the highest enforcement strength: discipline matters
  more than speed because the cost of an untracked tool is permanent
  silent drift in FEATURE-MAP. The "rigid for trivial tools" weak link
  is recoverable — skip Phase 3 audit deep dive when classify-first
  proves zero overlap in 30 seconds.

weakest_link: "Phase 4 atomicity assumes the agent finishes the whole sequence; if interrupted mid-commit, FEATURE-MAP and sync.config can drift apart. Doctor catches it."

last_synced: 2026-05-26T00:00:00Z
upstream_hash: ~
---

# add-tool

Run this whenever a new skill / MCP / plugin / CLI / agent harness
component is being considered. Output = updated FEATURE-MAP +
sync.config + (optional) composed skill regenerated + one git commit.

## When to fire

Triggers:
- "add a tool"
- "integrate <name>"
- "how do I wire up <name>"
- "where does <X> go"
- "install <Y>"
- Any user message naming a not-yet-installed npm package / GitHub repo /
  MCP server / Claude plugin.

## Quick path (zero-overlap tools)

If Phase 1 + Phase 3 take under 30 seconds and overlap = none:

1. Append FEATURE-MAP row.
2. Add sync.config entry (if it has a version surface).
3. Commit `feat(<domain>): add <tool>`.
4. Skip composed-skill edits.

## Full path (overlapping tools)

Follow the 6 phases in `compose_rule`. Use these concrete commands.

### Research

```bash
# npm package
opensrc path <pkg>                                      # cache path
rg "export|class|function" "$(opensrc path <pkg>)/src"  # surface

# GitHub repo
gh repo view <owner>/<repo> --json description,defaultBranchRef,homepageUrl
gh api repos/<owner>/<repo>/readme --jq .content | base64 -d | head -200

# MCP server — check claude.ai panel or plugin marketplace
claude mcp list --json | jq '.[] | select(.id == "<id>")'

# Library docs
# Use plugin:context7 — resolve-library-id then query-docs
```

### Audit overlap

```bash
grep -i "<keyword-role>" ~/Developer/oh-my-claudelin/FEATURE-MAP.md
(cd ~/Developer/skill-x && \
 SKILL_X_SKILLS_DIR=$HOME/Developer/oh-my-claudelin/skills \
 node tools/audit.mjs 2>&1 | head -30)
```

### Write back

Edit (in order, atomic):

1. `~/Developer/oh-my-claudelin/FEATURE-MAP.md` — domain section table + decision rule.
2. `~/Developer/oh-my-claudelin/sync.config.json` — new `parents.<id>` entry.
3. `~/Developer/oh-my-claudelin/skills/<domain>-best/SKILL.md` (if composed).

### Verify

```bash
bash ~/Developer/oh-my-claudelin/scripts/doctor.sh                # 11/11 ok
node ~/Developer/oh-my-claudelin/scripts/sync-parents.mjs         # new parent resolves
bash ~/Developer/oh-my-claudelin/scripts/install.sh               # relink (if new *-best)
```

### Commit

```bash
cd ~/Developer/oh-my-claudelin
git add FEATURE-MAP.md sync.config.json skills/<domain>-best/SKILL.md
git commit -m "feat(<domain>): add <tool> to the routing"
git push
```

## sync.config.json entry template

Always structured `cmd` + `args` (no shell strings — security):

```json
"<tool-id>": {
  "kind": "npm" | "github-release" | "claude-mcp" | "claude-builtin",
  "package": "<npm-pkg>",          // if kind=npm
  "repo": "<owner>/<repo>",        // if kind=github-release
  "id": "<mcp-id>",                // if kind=claude-mcp
  "cmd": "npm" | "gh" | "node" | "claude",
  "args": ["...", "...", "..."],
  "homepage": "https://..."
}
```

Allowed `cmd` values are pinned in `sync.config.json:allowedCmds` — extend
that list if a new tool needs a different binary.

## What this skill is NOT

- Not a generic "install npm package" script. Use npm directly for that.
- Not a substitute for reading the new tool's own docs. opensrc + context7
  surface the source; the skill picks placement, not implementation.
- Not idempotent — running twice on the same tool will detect "already
  mapped" in Phase 1 and exit early.

## What to do if a phase fails

| Failure | Action |
|---|---|
| opensrc path returns nothing (pkg not installed) | Try `npm install -g <pkg>` first, OR skip research and rely on gh README. |
| context7 has no docs for the lib | Fall back to `gh api repos/<owner>/<repo>/readme`. |
| audit finds no overlap but you suspect one | Manually grep FEATURE-MAP for the role nouns ("memory", "browser", "review"). |
| sync-parents.mjs fails to resolve the new parent | Check the `cmd` is in `allowedCmds`, args produce non-empty output, timeout is enough. |
| doctor.sh fails after edit | A composed skill body no longer contains the parent's name — fix the body, then re-run. |

## Drift signals (when add-tool itself ages)

- skill-x compose contract changes (`composed_from` etc.) → re-validate this SKILL.md frontmatter.
- FEATURE-MAP structure changes (new domain category) → update Phase 1 classification list.
- New install commands beyond npm/gh/node/claude → update `allowedCmds` enforcement note.

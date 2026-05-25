---
name: browser-best
description: "Route browser work to the right tool: claude-in-chrome for auth/sessions on the user's Chrome, proofshot for visual PR verification with video+server logs, agent-browser for token-efficient navigation, firecrawl for pure content extraction. Use when the user asks to open/navigate/click/scrape/verify any web page, or to record a verification artifact for a PR."
category: decision-layer
tags: [browser, automation, verification]
keywords: [browser, chrome, playwright, scrape, screenshot, video, pr-verification]
sources: []
composed_from:
  - claude-in-chrome
  - proofshot
  - agent-browser
  - firecrawl
compose_rule: |
  Pick exactly one engine per task. Never run two browsers in parallel for the same goal.

  Decision tree:
    1. Does the task need the user's logged-in session (Gmail, GitHub UI, internal SaaS)?
       → claude-in-chrome. It connects to the user's real Chrome; auth comes for free.

    2. Is the task "verify this PR / feature visually for a human reviewer"?
       → proofshot. It starts the dev server (--run "npm run dev" --port 3000), records
         video, captures server logs across stacks, and posts a media bundle to the PR.
         proofshot wraps agent-browser under the hood — do not double-orchestrate.

    3. Is the task fast, programmatic, token-efficient navigation in a clean Chromium
       (no auth, no recording, no PR)?
       → agent-browser. Use the `snapshot -i` → `click @e1` / `fill @e2` pattern. Saves
         ~90% tokens vs raw DOM. State persistence via `agent-browser state save/load`.

    4. Pure content extraction — no interaction, just give me the page as markdown?
       → firecrawl. Skip the browser entirely.

  Never:
    - Use browser-harness (removed — superseded by this stack).
    - Use chrome-devtools-mcp (removed — overlaps claude-in-chrome).
    - Use agent-browser directly when proofshot is already running; pipe through `proofshot exec`.

  Synergy: proofshot → agent-browser → Chrome for Testing is a vertical stack. claude-in-chrome
  is parallel/orthogonal (the user's real browser).

compose_variants:
  - id: auth-first
    summary: "claude-in-chrome as primary; proofshot+agent-browser only for clean-room verification"
    weakest_link: "verification recordings include user's accidental state (other tabs, notifications)"
  - id: clean-room-first
    summary: "proofshot+agent-browser default; claude-in-chrome only when auth fails"
    weakest_link: "every auth-bearing task hits a detour through manual login"
  - id: route-by-intent
    summary: "Decision tree above — auth need → claude-in-chrome, verification need → proofshot, raw nav → agent-browser, scrape → firecrawl"
    weakest_link: "requires the agent to correctly classify intent each time; mis-route costs a retry"

selected: route-by-intent
selection_rationale: |
  auth-first conflates two different needs (user session vs clean recording) and pollutes
  verification artifacts with the user's incidental state.
  clean-room-first front-loads auth pain on every internal-tool task — proofshot has no auth
  vault, so this routes most real work through a manual login detour.
  route-by-intent has one weak link (classification), but it's local and recoverable — a
  mis-classified call wastes one round trip, not the whole session.

weakest_link: "If proofshot's underlying agent-browser version skews from a directly-invoked agent-browser, action semantics can differ. sync.config.json tracks both."

last_synced: 2026-05-26T00:00:00Z
upstream_hash: ~
---

# browser-best

Use the decision tree in `compose_rule` above. Concrete invocations below.

## 1. User's logged-in Chrome (auth/session)

Use the `mcp__claude-in-chrome__*` MCP tools. Load via ToolSearch first:

```
ToolSearch select:mcp__claude-in-chrome__tabs_context_mcp
ToolSearch select:mcp__claude-in-chrome__tabs_create_mcp
ToolSearch select:mcp__claude-in-chrome__navigate
```

Always start with `tabs_context_mcp` to learn the user's open tabs; prefer creating a new tab over reusing one.

## 2. Visual PR verification

```bash
proofshot start --run "npm run dev" --port 3000
proofshot exec open http://localhost:3000
proofshot exec snapshot -i
proofshot exec click @e1
# ... drive the flow ...
proofshot stop
proofshot pr <PR_NUMBER>  # posts media to the GitHub PR
```

## 3. Token-efficient navigation (no auth, no recording)

```bash
agent-browser open <url>
agent-browser snapshot -i      # → [E1] Combobox ..., [E2] Link ...
agent-browser click @e1
agent-browser fill @e2 "text"
agent-browser state save /path/to/state.json   # persist cookies/localStorage
```

## 4. Pure scrape

Use the `firecrawl` skill. CLI:

```bash
firecrawl scrape <url> --format markdown
```

## What NOT to do

- Do not start a second browser when one of the above is already serving the goal.
- Do not pipe `agent-browser` commands around an active `proofshot` session — use `proofshot exec`.
- Do not use removed tools: `browser-harness`, `chrome-devtools-mcp`.

## Drift signals (monitored by sync.config.json)

- `npm view proofshot version`
- `npm view agent-browser version`
- claude-in-chrome MCP server version (whatever the active session reports)

When any of these moves, `scripts/update.sh` flags this skill for re-composition.

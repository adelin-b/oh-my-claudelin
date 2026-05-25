---
name: docs-best
description: "Route documentation lookups: plugin:context7 for library/SDK/framework docs (versioned), opensrc for reading actual installed source code, omc:document-specialist for repo-internal docs, WebFetch as last resort. Use whenever the user asks how a library works, how to use an API, what a function does, or how a project is structured."
category: decision-layer
tags: [docs, reference, lookup]
keywords: [docs, documentation, reference, api, library, source]
sources: []
composed_from:
  - plugin:context7
  - opensrc
  - omc:document-specialist
  - builtin:WebFetch
compose_rule: |
  Pick by what is being looked up.

  Decision tree:
    1. "How do I use library X" / "What changed in version Y" / "What's the signature of Z"?
       → plugin:context7. resolve-library-id then query-docs. Versioned, official.

    2. "How does function X actually work" / "Verify behavior at the locked version we have"?
       → opensrc. `rg "..." "$(opensrc path <pkg>)"` or `cat "$(opensrc path <pkg>)/src/..."`
         Reads the actual installed code, not docs. Critical when docs and code disagree.

    3. "Where is X in this repo / what does this design doc say"?
       → omc:document-specialist. Internal repo docs first; falls back gracefully.

    4. Nothing else fits (blog post, RFC, vendor announcement)?
       → WebFetch / WebSearch.

  ALWAYS prefer context7 over WebFetch for library questions — training data may be stale
  and WebFetch loses version context.

  ALWAYS prefer opensrc over reading from node_modules manually — opensrc caches, picks
  the locked version, and works for npm/PyPI/crates/GitHub uniformly.

  NEVER:
    - Use claude.ai Context7 (duplicate of plugin:context7 — disable in claude.ai panel).
    - Guess from memory when context7 can answer — training data is months stale.

  Synergy: context7 to learn the API shape → opensrc to verify the implementation in the
  version you're locked to → if the two disagree, file the bug; do not silently work
  around it.

compose_variants:
  - id: docs-first
    summary: "Always try context7 first; opensrc only when docs are insufficient."
    weakest_link: "Burns docs lookups on simple 'what does this function return' questions where reading the source is one rg away."
  - id: source-first
    summary: "Always read source via opensrc; docs only for context."
    weakest_link: "Source-only loses official guidance on intended usage / deprecation timelines."
  - id: question-routed
    summary: "Decision tree above — API/version question → context7, behavior question → opensrc, repo question → document-specialist, last-resort → WebFetch."
    weakest_link: "Requires classifying the question type; some questions are both API and behavior."

selected: question-routed
selection_rationale: |
  docs-first is wasteful for behavior questions (one rg vs an API call). source-first
  loses official deprecation and recommended-usage signals. question-routed's weak link
  is the easiest to recover — if classification was wrong, the other tool is one call
  away with no state lost.

weakest_link: "context7 versioning is best-effort — for cutting-edge or pre-release libraries, opensrc on the installed version is the only trustworthy answer."

last_synced: 2026-05-26T00:00:00Z
upstream_hash: ~
---

# docs-best

## Quick map

| Question | Tool | Invocation |
|---|---|---|
| API shape, version diff, official guidance | plugin:context7 | `resolve-library-id` then `query-docs` |
| What does this function actually do (locked version) | opensrc | `rg "..." "$(opensrc path <pkg>)"` |
| Repo-internal architecture, design doc | omc:document-specialist | Task tool |
| Blog post, RFC, vendor announcement | WebFetch | last resort |

## opensrc idioms

```bash
# Print path (fetches on cache miss). Quote because paths may contain spaces.
opensrc path zod                    # npm default
opensrc path pypi:requests
opensrc path crates:serde
opensrc path vercel/next.js         # GitHub repo

# Search source
rg "function parse" "$(opensrc path zod)"

# Read specific file
cat "$(opensrc path zod)/src/types.ts"

# Pre-fetch (script / CI)
opensrc fetch zod react
```

## What NOT to do

- Don't use claude.ai Context7 if plugin:context7 is installed (duplicate).
- Don't read from `node_modules/` directly — use opensrc (cache + version pinning).
- Don't WebSearch for "how does X library work" when context7 has it.

## Drift signals

- context7 plugin release tag
- opensrc release tag (`gh api repos/vercel-labs/opensrc/releases/latest --jq .tag_name`)
- OMC release tag (document-specialist ships with OMC)

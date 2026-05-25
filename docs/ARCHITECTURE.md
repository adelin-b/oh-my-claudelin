# Architecture

## Two-repo model

```
upstream:  Yeachan-Heo/oh-my-claudecode   (the source OMC repo, 34k stars)
              ▲ git pull (clean, never modified)
              │
fork:      adelin-b/oh-my-claudecode      (mirror; only upstream-PRable patches live here)
              │
              │  installed as plugin via marketplace add
              ▼
runtime:   ~/.claude/plugins/cache/omc/oh-my-claudecode/<version>/
              ▲
              │  symlinked / merged at session start
              │
overlay:   adelin-b/oh-my-claudelin       (this repo — additive overlay)
              ├── skills/*-best/SKILL.md       composed skills
              ├── compose-rules/*.yaml         compose inputs
              ├── overrides/                   (optional) personal patches for OMC files
              ├── sync.config.json             parent skills tracked for drift
              ├── hooks.spec.json              skill-x hook generator input
              ├── .claude-plugin/plugin.json   Claude plugin manifest
              └── scripts/{install,update,compose,doctor}.sh
```

## Why overlay, not patches

A long-lived fork-with-patches breaks on every upstream pull. `adelin-b/oh-my-claudecode` exists only as the cleanest possible upstream mirror, kept around in case a change is ever worth PRing back to Yeachan-Heo.

All personal work lives in the overlay repo and only ever:
- adds new skills, agents, MCPs, commands
- overrides specific OMC files by name (rare — kept in `overrides/`)
- changes plugin manifest entries via `plugin.json`

Upstream OMC never knows about the overlay. The overlay knows about OMC's public skill names so it can compose with them.

## Composed skills (skill-x contract)

Every `skills/*-best/SKILL.md` is a derived skill — not a hand-written replacement. Its frontmatter records the lineage:

```yaml
composed_from: [parentA, parentB, parentC]
compose_rule: |
  When the user wants ___, route to ___; when ___, route to ___; etc.
compose_variants:
  - id: variant-a
    summary: ...
    weakest_link: ...
selected: variant-a
selection_rationale: |
  Why this variant beat the others.
last_synced: <ISO timestamp>
upstream_hash: sha256:<hash of all sources>
```

When a parent skill drifts (new version, changed body, deprecated trigger), `skill-x` `skill-sync` detects it and queues the derived skill for `skill-x` `skill-compose` to regenerate. The composed SKILL.md is then committed to the overlay repo — the regeneration is fully versioned.

## Truth source designation

`FEATURE-MAP.md` is the only place that says "for domain X, tool T is canonical." Code, scripts, and composed skills reference the map by domain name. Adding a tool starts there; otherwise overlaps proliferate silently.

## Install lifecycle

1. `bash scripts/install.sh`:
   - Validates OMC plugin is installed (errors with a one-liner fix if not).
   - For each `skills/*-best/SKILL.md`, creates a symlink in `~/.claude/skills/` for instant dev use.
   - Registers the overlay as a Claude plugin via `claude plugin marketplace add file://$PWD` + `claude plugin install oh-my-claudelin@local` so the manifest gets picked up too.
   - Writes a `.skill-x-state/install-stamp.json` for `doctor.sh`.
2. Subsequent sessions automatically load both OMC and overlay skills.

## Update lifecycle

`bash scripts/update.sh`:
1. `git -C ~/Developer/oh-my-claudelin pull --rebase`.
2. `cd ~/Developer/oh-my-claudecode-fork && git fetch upstream && git pull upstream main && git push origin main` (keeps fork mirror current).
3. `node ~/Developer/skill-x/tools/sync.mjs --config sync.config.json` (drift detection against tracked parents).
4. For each drifted parent → `node ~/Developer/skill-x/tools/compose.mjs --rule compose-rules/<domain>.yaml --out skills/<domain>-best/SKILL.md`.
5. `git commit -am "chore: drift sync $(date -Iseconds)"` if anything changed.
6. Re-run symlinks in case a new `*-best` skill was added.

## Add-a-tool lifecycle

See [`ADD-A-TOOL.md`](./ADD-A-TOOL.md).

## Removal lifecycle

When a tool is removed:
1. Mark `❌` in `FEATURE-MAP.md` with one-line reason.
2. Strip from `composed_from:` of any affected `compose-rules/*.yaml`.
3. `bash scripts/compose.sh <domain>` to regenerate.
4. Optional: `claude plugin uninstall <name>` or `rm -rf ~/.claude/skills/<name>`.

## Where the wiring lives

| Wiring | File |
|---|---|
| Plugin manifest (Claude picks this up) | `.claude-plugin/plugin.json` |
| Plugin marketplace metadata | `.claude-plugin/marketplace.json` |
| Hooks (generated per-tool) | `hooks.spec.json` → `tools/gen-hooks.mjs` (from skill-x) |
| Drift-tracked parents | `sync.config.json` |
| Compose rules | `compose-rules/<domain>.yaml` |
| Composed outputs | `skills/<domain>-best/SKILL.md` |
| Truth source map | `FEATURE-MAP.md` |

# Add a new tool

The single discipline that keeps this overlay useful: every new tool starts in `FEATURE-MAP.md`, not in code.

## Workflow

### 1. Map the tool

Open `FEATURE-MAP.md`. Find the domain row(s) the tool touches. Append a row with:

- name
- type (skill / MCP / plugin / CLI / built-in)
- status (✅ / 🟡 / ❌)
- one-line role

If the tool spans multiple domains, add a row under each.

### 2. Audit for overlap

```bash
cd ~/Developer/oh-my-claudelin
# Quick scan (heuristic): grep map for similar role phrases
grep -i "<keyword>" FEATURE-MAP.md

# Full audit via skill-x (when run inside this repo)
(cd ~/Developer/skill-x && SKILL_X_SKILLS_DIR="$HOME/Developer/oh-my-claudelin/skills" node tools/audit.mjs)
```

The audit surfaces:
- Skills with overlapping triggers
- Composed skills whose parents now include redundant entries
- Stale primaries

### 3. Decide: standalone or composed

| Situation | Action |
|---|---|
| No overlap with anything existing | Standalone — just leave the map row. No composed skill needed. |
| Overlaps 1 existing tool but covers a different lifecycle stage | Add to the relevant `*-best/SKILL.md` `composed_from:` + a new line in the decision tree. |
| Overlaps multiple tools with no clear winner | Add a new composed `*-best/SKILL.md` with a compose_rule that picks a winner. |
| Pure duplicate | Mark the new tool ❌ and don't install, OR mark the old one ❌ if the new one is better. |

### 4. Update the affected composed skill

Open `skills/<domain>-best/SKILL.md`. Edit:
- `composed_from:` — append the new parent's identifier
- `compose_rule:` — add a numbered branch in the decision tree
- `compose_variants:` — if the new tool implies a new selection variant
- `selected:` / `selection_rationale:` — if the winner changes
- `last_synced:` — bump
- `upstream_hash:` — set to `~` so next sync-parents recomputes

### 5. Track upstream for drift

Open `sync.config.json`. Add a `parents.<name>` entry with `kind` and `check`:

```json
"<tool-name>": {
  "kind": "npm" | "github-release" | "claude-mcp" | "claude-builtin",
  "package": "<npm package>",            // if kind=npm
  "repo": "<owner/repo>",                // if kind=github-release
  "id": "<MCP server id>",               // if kind=claude-mcp
  "check": "<shell command that prints a version-like string>"
}
```

### 6. Commit atomically

```bash
git add FEATURE-MAP.md sync.config.json skills/<domain>-best/SKILL.md
git commit -m "feat(<domain>): add <tool-name> to the routing"
```

One commit per tool add. Makes drift bisectable.

### 7. Verify

```bash
bash scripts/doctor.sh
```

Should pass. If a new composed skill was added, `install.sh` will be re-run by doctor to link it.

## When NOT to compose

- The new tool's role doesn't overlap anything → no composed skill needed; the map row suffices.
- The tool is a project-scoped specialty (e.g., a one-bug-fix skill) → keep it as a standalone skill; don't try to merge it.
- The tool is being trialed → keep as standalone first; promote to composed only after it earns its place.

# Upgrade

## Daily

```bash
bash ~/Developer/oh-my-claudelin/scripts/update.sh
```

Pulls overlay, pulls fork from upstream (if cloned locally), runs drift detection, surfaces composed skills that need re-composition.

## When a parent drifts

`update.sh` prints something like:

```
  *  proofshot 0.4.1 → 0.5.0  [DRIFT]
  *  agent-browser 0.12.3 → 0.13.0  [DRIFT]

Composed skills that may need re-composition:
  - skills/browser-best/SKILL.md
```

Open Claude Code and ask:

> Re-author skills/browser-best/SKILL.md per its compose_rule, given that proofshot moved to 0.5.0 and agent-browser to 0.13.0. Read FEATURE-MAP.md section 1 and manifest/{proofshot,agent-browser}.json. Preserve compose_variants and selected; bump last_synced and refresh upstream_hash.

The agent uses the embedded `compose_rule` + the changelog of the drifted parents to rewrite the body. Commit the result.

## Upstream OMC release

`update.sh` syncs the OMC fork mirror automatically (`~/Developer/oh-my-claudecode-fork` if present). The actual OMC plugin updates via Claude's marketplace:

```
/plugin update oh-my-claudecode@omc
```

If an OMC skill referenced in a composed_from list was renamed or removed, the affected `*-best/SKILL.md` is flagged by `sync-parents.mjs` and re-compose is needed.

## skill-x upgrade

```bash
git -C ~/Developer/skill-x pull
(cd ~/Developer/skill-x && npm install)
```

If skill-x changes the frontmatter contract, run:

```bash
(cd ~/Developer/skill-x && SKILL_X_SKILLS_DIR=$HOME/Developer/oh-my-claudelin/skills node tools/skill-validate.mjs)
```

Fix any reported violations in our SKILL.md files.

## Repo move

If the overlay repo moves on disk, re-run `bash scripts/install.sh`. It re-creates the symlinks to the new path.

## Reset

```bash
# Remove all symlinks created by install.sh
for s in browser-best memory-best review-best docs-best; do
  rm -f ~/.claude/skills/"$s"
done

# Uninstall plugin
claude plugin uninstall oh-my-claudelin@local 2>/dev/null || true

# Optionally delete the repo
rm -rf ~/Developer/oh-my-claudelin
```

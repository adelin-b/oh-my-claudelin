#!/usr/bin/env bash
# compose.sh — placeholder for in-context skill recomposition.
#
# Background: skill-x compose.mjs DETECTS staleness but does not rewrite SKILL.md
# bodies. The rewrite is done by an agent (skill-compose SKILL in Claude Code)
# reading the stale report + the existing SKILL.md's `compose_rule` and
# re-authoring the body.
#
# This script just prints the stale list and the prompt to feed to the agent.
set -euo pipefail

OVERLAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-}"

if [ -d "${HOME}/Developer/skill-x" ]; then
  echo "==> skill-x compose detection"
  (cd "${OVERLAY_DIR}" && \
    SKILL_X_SKILLS_DIR="skills" \
    node "${HOME}/Developer/skill-x/tools/compose.mjs" ${TARGET:+--skill "$TARGET"})
fi

echo "==> Parent drift"
node "${OVERLAY_DIR}/scripts/sync-parents.mjs" --report

cat <<'EOF'

==> To regenerate a stale SKILL.md, run this in Claude Code:

  Read skills/<name>-best/SKILL.md
  Read FEATURE-MAP.md (the relevant section)
  Read manifest/<parent>.json for each drifted parent
  Re-author the body of skills/<name>-best/SKILL.md according to its compose_rule,
  updating last_synced and upstream_hash. Preserve compose_variants and selected.

EOF

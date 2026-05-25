#!/usr/bin/env bash
# doctor.sh — verify the overlay install + drift state.
set -euo pipefail

OVERLAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS="${HOME}/.claude/skills"
PASS=0
FAIL=0

ok()   { echo "  ok    $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "==> oh-my-claudelin doctor"

# 1. OMC installed?
if [ -d "${HOME}/.claude/plugins/cache/omc/oh-my-claudecode" ]; then
  ok "OMC plugin installed"
else
  fail "OMC plugin missing (required prereq)"
fi

# 2. skill-x available?
if [ -d "${HOME}/Developer/skill-x" ]; then
  ok "skill-x cloned at ~/Developer/skill-x"
else
  fail "skill-x not cloned (drift cascade will be limited)"
fi

# 3. Each composed skill symlinked?
for skill_dir in "${OVERLAY_DIR}"/skills/*/; do
  name="$(basename "${skill_dir}")"
  link="${CLAUDE_SKILLS}/${name}"
  if [ -L "${link}" ] && [ "$(readlink "${link}")" = "${skill_dir%/}" ]; then
    ok "${name} symlinked"
  else
    fail "${name} NOT symlinked (run scripts/install.sh)"
  fi
done

# 4. Each composed skill's SKILL.md valid frontmatter?
for skill_dir in "${OVERLAY_DIR}"/skills/*/; do
  name="$(basename "${skill_dir}")"
  md="${skill_dir}/SKILL.md"
  if grep -q "^composed_from:" "${md}" && grep -q "^compose_rule:" "${md}"; then
    ok "${name} frontmatter has composed_from + compose_rule"
  else
    fail "${name} frontmatter missing composed_from or compose_rule"
  fi
done

# 5. Plugin manifest present?
if [ -f "${OVERLAY_DIR}/.claude-plugin/plugin.json" ]; then
  ok "plugin.json present"
else
  fail "plugin.json missing"
fi

# 6. Parent drift snapshot
echo ""
echo "==> Parent drift"
node "${OVERLAY_DIR}/scripts/sync-parents.mjs" --report --quiet || true

echo ""
echo "==> Result: ${PASS} ok / ${FAIL} fail"
[ "${FAIL}" -eq 0 ]

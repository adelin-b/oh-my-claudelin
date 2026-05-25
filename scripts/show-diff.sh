#!/usr/bin/env bash
# show-diff.sh — visualize what oh-my-claudelin overlay adds over vanilla OMC.
# Two sections: (1) fork-vs-upstream OMC, (2) overlay file tree + per-skill lineage.
set -euo pipefail

OVERLAY="${HOME}/Developer/oh-my-claudelin"
FORK="${HOME}/Developer/oh-my-claudecode-fork"

bold()  { printf '\033[1m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
yellow(){ printf '\033[33m%s\033[0m' "$1"; }
cyan()  { printf '\033[36m%s\033[0m' "$1"; }

bold "═══ oh-my-claudelin — what changed vs vanilla OMC ═══"
echo

# --- 1. Fork mirror status
bold "1. Fork mirror (adelin-b/oh-my-claudecode) vs upstream (Yeachan-Heo)"
if [ -d "${FORK}/.git" ]; then
  cd "${FORK}"
  AHEAD=$(git rev-list --count upstream/main..main 2>/dev/null || echo "?")
  BEHIND=$(git rev-list --count main..upstream/main 2>/dev/null || echo "?")
  echo "  ahead: $(green "${AHEAD}")  behind: $(yellow "${BEHIND}")"
  if [ "${AHEAD}" = "0" ] && [ "${BEHIND}" = "0" ]; then
    echo "  → $(green "clean mirror") — no local patches, no upstream lag"
  fi
else
  dim "  (fork not cloned locally — skipping)"
fi
echo

# --- 2. Overlay content
cd "${OVERLAY}"
bold "2. Overlay surface (adelin-b/oh-my-claudelin)"
echo
dim "  Commits:"
git log --oneline | sed 's/^/    /'
echo
dim "  File tree:"
git ls-tree -r --name-only HEAD | grep -vE '^\.gitignore$|^manifest/' | sort | sed 's/^/    /'
echo
dim "  Composed skills + lineage:"
for skill_md in skills/*/SKILL.md; do
  name=$(grep -m1 '^name:' "${skill_md}" | awk '{print $2}')
  echo "    $(cyan "${name}")"
  awk '/^composed_from:/,/^[a-z_]+:/' "${skill_md}" \
    | grep -E '^  - ' \
    | sed 's/^  - /        ↳ /'
done
echo

# --- 3. Drift state
bold "3. Drift state"
node "${OVERLAY}/scripts/sync-parents.mjs" --report --quiet 2>&1 | sed 's/^/  /'
echo

# --- 4. Plugin manifest summary
bold "4. Plugin manifest (.claude-plugin/plugin.json)"
echo "  skills exposed:"
grep -E '"./skills' .claude-plugin/plugin.json | sed 's/^[[:space:]]*//;s/^/    /'
echo

# --- 5. FEATURE-MAP stats
bold "5. FEATURE-MAP truth source"
DOMAINS=$(grep -cE '^## [0-9]+\.' FEATURE-MAP.md || echo 0)
TOOLS=$(grep -cE '^\| [a-zA-Z0-9@:/_-]+ \| ' FEATURE-MAP.md || echo 0)
echo "  domains mapped: $(green "${DOMAINS}")"
echo "  tool rows:      $(green "${TOOLS}")"
echo

bold "═══ end ═══"

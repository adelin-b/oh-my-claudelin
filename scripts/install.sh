#!/usr/bin/env bash
# install.sh — wire the overlay into ~/.claude in dev-friendly + plugin-registered modes.
set -euo pipefail

OVERLAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
STATE_DIR="${OVERLAY_DIR}/.skill-x-state"

echo "==> Installing oh-my-claudelin from ${OVERLAY_DIR}"

mkdir -p "${SKILLS_DIR}" "${STATE_DIR}"

# --- 1. OMC prereq check
if [ ! -d "${HOME}/.claude/plugins/cache/omc/oh-my-claudecode" ]; then
  echo "ERROR: oh-my-claudecode plugin not installed."
  echo "Install: /plugin marketplace add omc Yeachan-Heo/oh-my-claudecode"
  echo "         /plugin install oh-my-claudecode@omc"
  exit 1
fi

# --- 2. skill-x prereq check (we use its compose/sync tools)
if [ ! -d "${HOME}/Developer/skill-x" ]; then
  echo "WARN: skill-x not at ~/Developer/skill-x. Drift detection limited."
  echo "Clone: git clone https://github.com/adelin-b/skill-cross-integration.git ~/Developer/skill-x"
fi

# --- 3. Symlink each composed skill into ~/.claude/skills for instant dev pickup
for skill_dir in "${OVERLAY_DIR}"/skills/*/; do
  name="$(basename "${skill_dir}")"
  link="${SKILLS_DIR}/${name}"
  if [ -L "${link}" ]; then
    rm "${link}"
  elif [ -e "${link}" ]; then
    echo "WARN: ${link} exists and is not a symlink. Skipping. Move it aside to install."
    continue
  fi
  ln -s "${skill_dir%/}" "${link}"
  echo "  linked ${name} → ${skill_dir%/}"
done

# --- 4. Register as Claude plugin (marketplace + install)
if command -v claude >/dev/null 2>&1; then
  echo "==> Registering plugin via claude CLI"
  # marketplace add accepts a local path
  claude plugin marketplace add "file://${OVERLAY_DIR}" 2>/dev/null || true
  claude plugin install "oh-my-claudelin@local" 2>/dev/null || \
    claude plugin install "oh-my-claudelin@oh-my-claudelin" 2>/dev/null || \
    echo "  (plugin marketplace registration may need manual: /plugin marketplace add file://${OVERLAY_DIR})"
else
  echo "WARN: claude CLI not on PATH. Run manually: /plugin marketplace add file://${OVERLAY_DIR}"
fi

# --- 5. Stamp install state
cat > "${STATE_DIR}/install-stamp.json" <<JSON
{
  "installedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "overlayDir": "${OVERLAY_DIR}",
  "skillsLinked": [$(for d in "${OVERLAY_DIR}"/skills/*/; do echo -n "\"$(basename "$d")\","; done | sed 's/,$//')]
}
JSON

echo "==> Done."
echo "Verify: bash scripts/doctor.sh"

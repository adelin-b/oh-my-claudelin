#!/usr/bin/env bash
# update.sh — daily sync. Pulls OMC fork from upstream, runs drift detection,
# regenerates composed skills if parents drifted, commits, re-links.
set -euo pipefail

OVERLAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORK_DIR="${HOME}/Developer/oh-my-claudecode-fork"

echo "==> Pulling overlay"
git -C "${OVERLAY_DIR}" pull --rebase

# --- OMC fork mirror sync (optional — only if locally cloned)
if [ -d "${FORK_DIR}/.git" ]; then
  echo "==> Syncing OMC fork mirror at ${FORK_DIR}"
  git -C "${FORK_DIR}" fetch upstream 2>/dev/null || \
    git -C "${FORK_DIR}" remote add upstream https://github.com/Yeachan-Heo/oh-my-claudecode.git
  git -C "${FORK_DIR}" fetch upstream
  git -C "${FORK_DIR}" checkout main
  git -C "${FORK_DIR}" merge --ff-only upstream/main || {
    echo "WARN: fork main has diverged from upstream — leaving as-is. Resolve manually."
  }
  git -C "${FORK_DIR}" push origin main || true
else
  echo "(skip fork sync — ${FORK_DIR} not present)"
fi

# --- Drift detection
echo "==> Checking parent drift"
node "${OVERLAY_DIR}/scripts/sync-parents.mjs" --report || true

# --- skill-x compose detection (only for skill-x-tracked parents)
if [ -d "${HOME}/Developer/skill-x" ]; then
  echo "==> Running skill-x compose detection"
  (cd "${OVERLAY_DIR}" && \
    SKILL_X_SKILLS_DIR="skills" node "${HOME}/Developer/skill-x/tools/compose.mjs" || true)
fi

# --- Re-link any new skills
echo "==> Re-linking skills"
bash "${OVERLAY_DIR}/scripts/install.sh" >/dev/null

# --- Commit any drift updates
if ! git -C "${OVERLAY_DIR}" diff --quiet; then
  echo "==> Committing drift updates"
  git -C "${OVERLAY_DIR}" add -A
  git -C "${OVERLAY_DIR}" commit -m "chore: drift sync $(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi

echo "==> Done."

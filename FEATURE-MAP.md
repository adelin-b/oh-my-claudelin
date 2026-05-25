# FEATURE-MAP

The single truth source for every tool installed across Adelin's Claude Code stack. For each capability domain:

- **Tools installed** — every skill, MCP, plugin, CLI, or built-in that touches the domain
- **Overlap** — where two tools claim the same job
- **Truth source** — the one tool that owns the canonical job
- **Decision rule** — when more than one tool legitimately applies, the rule that routes between them
- **Synergy** — how tools stack (not compete)

Updated whenever a tool is added or removed. Audited by `npm run audit` (skill-x).

Legend: ✅ canonical truth · 🟡 alternative in decision rule · ❌ flagged for removal

---

## 1. Browser automation

| Tool | Type | Status | Role |
|---|---|---|---|
| claude-in-chrome | MCP | ✅ | Real Chrome with user's auth, sessions, cookies. Long-running browser work. |
| proofshot | CLI + skill | ✅ | Visual verification loop: video recording, server-log capture, GitHub PR media bundles. Wraps agent-browser. |
| agent-browser | CLI | ✅ | Low-level Rust+Node engine. Token-efficient accessibility-tree interaction (`@e1` refs). Backend for proofshot. |
| browser-harness | local skill (`~/Developer/browser-harness`) | ❌ removed | Custom CDP harness — superseded by claude-in-chrome for auth + proofshot for verification. |
| chrome-devtools-mcp | plugin | ❌ removed | Devtools-panel automation — redundant with claude-in-chrome CDP. |
| cmux-browser | skill | 🟡 | Drives cmux internal webview surfaces only. Specialty. |
| superset-browser | skill | 🟡 | Drives Superset.app integrated webviews only. Specialty. |
| firecrawl | skill | ✅ | Web scraping (markdown extraction, search, site crawl). NOT browser automation — content extraction. |

**Decision rule** (composed in `browser-best`):
1. Need user auth / session / cookies / running on the user's machine browser → **claude-in-chrome**.
2. Need to record video, capture server logs, post a verification artifact to a PR → **proofshot** (starts agent-browser under the hood).
3. Need raw token-efficient navigation in a clean Chromium → **agent-browser** directly (no proofshot orchestration).
4. Need page content as markdown (no interaction) → **firecrawl**.
5. cmux or Superset internal webview → the specialty skill.

**Synergy:** proofshot → agent-browser → Chrome for Testing. Stack, not compete.

---

## 2. Memory / state / knowledge

| Tool | Type | Status | Role |
|---|---|---|---|
| auto-memory | built-in (`~/.claude/projects/-Users-adelinb/memory/`) | ✅ | Cross-session facts about user, feedback, projects, references. Auto-loaded into every session start. Markdown files + MEMORY.md index. |
| ctx-mode | MCP plugin | ✅ | Per-session sandbox. `ctx_execute` keeps raw bytes out of the conversation; `ctx_search` queries indexed captures + timeline. |
| omc:wiki | OMC skill | ✅ | Karpathy-style persistent markdown wiki for a project. Compounds across sessions, scoped to the project tree. |
| mex (`mex-agent`) | npm CLI | ✅ | Structured agent memory scaffold (AGENTS.md/ROUTER.md/context/patterns) + drift CLI (`mex check`, `mex sync`). |
| OMC notepad (notepad_*) | MCP tools | 🟡 | Working/priority/manual notes inside an OMC session. Subset of wiki use. |
| OMC project_memory / shared_memory | MCP tools | 🟡 | Cross-agent shared memory inside OMC team runs. Specialty. |
| graphiti-memory | skill | ❌ removed | Neo4j/FalkorDB graph memory. Heavy infra, low usage. |
| graphify | skill | ❌ removed | Code/docs/papers → knowledge graph. Overlaps graphiti. |
| codegraph-context (CGC) | skill | 🟡 | Structural code analysis (call graphs, callers, dead code). Different angle from memory — structural code intelligence. |
| ragflow | skill | ⚠ scoped | Now project-scoped to better-chatvote only. Not global. |
| OMC remember / note | skills | 🟡 | UX shortcuts that ultimately write to wiki or auto-memory. |

**Decision rule** (composed in `memory-best`):
1. A fact about the user, their preferences, their projects, or feedback that should survive every session → **auto-memory** (`.claude/projects/<proj>/memory/`).
2. A working capture/intermediate result for THIS session, where bytes shouldn't pollute context → **ctx-mode** (`ctx_execute`, `ctx_search`).
3. Project-scoped knowledge that compounds across sessions for the same repo (architecture decisions, gotchas, runbooks) → **omc:wiki**.
4. Structured project memory scaffold + drift detection (AGENTS.md/ROUTER.md/context/patterns) that the agent reads on every cold start → **mex**.
5. Inside an OMC team run, share state between agents → **OMC shared_memory**.
6. Codebase call-graph / dependency questions → **codegraph-context** (NOT memory; structural code intel).

**Truth source for "what is this user/project?"**: auto-memory.
**Truth source for "what does this codebase contain and how is it organized?"**: mex scaffold (if present) > omc:wiki > AGENTS.md > CLAUDE.md.

**Synergy:** mex `ROUTER.md` can point at omc:wiki pages; auto-memory entries can link to mex `context/` files.

---

## 3. Code review

| Tool | Type | Status | Role |
|---|---|---|---|
| omc:code-reviewer | OMC agent (opus) | ✅ | Deep code review with severity-rated findings. Use for pre-commit / pre-PR locally. |
| omc:verifier | OMC agent | ✅ | Verification-before-completion: runs evidence checks, blocks false success claims. |
| built-in `/review` | built-in skill | ✅ | Reviews current diff or a GitHub PR. Inline GH PR comments via `--comment`. |
| pr-review-toolkit | plugin | ❌ removed | review-pr + per-domain agents. OMC stack covers. |
| feature-dev | plugin | ❌ removed | code-architect/explorer/reviewer agents. OMC architect/explore/code-reviewer cover. |
| code-review@official | plugin | ❌ removed | Duplicate of built-in `/review`. |
| code-review@plugins (kept marketplace dup) | plugin | ❌ removed | Marketplace dedupe. |
| caveman:cavecrew-reviewer | agent | 🟡 | Caveman-compressed terse reviewer. Kept (caveman mode is in active use). |
| omc:critic | OMC agent (opus) | 🟡 | Reviews PLANS not code. |

**Decision rule** (composed in `review-best`):
1. PR on GitHub, posting findings inline → **built-in `/review --comment`**.
2. Local pre-commit deep review with reasoning → **omc:code-reviewer** (model=opus).
3. "Is this really done?" gate before claiming completion → **omc:verifier**.
4. Review of a plan/spec (not code) → **omc:critic**.
5. Want terse caveman-mode review → **caveman:cavecrew-reviewer**.

**Synergy:** verifier runs AFTER code-reviewer pass green; `/review` outputs feed back into a follow-up `omc:executor` fix loop.

---

## 4. Docs lookup

| Tool | Type | Status | Role |
|---|---|---|---|
| plugin:context7 | MCP | ✅ | Versioned library/framework/SDK docs. Resolve-library-id → query-docs. |
| claude.ai Context7 | MCP (claude.ai panel) | ❌ remove | Duplicate of plugin variant. Disable in claude.ai integrations. |
| opensrc | local CLI (`~/.local/bin/opensrc`) | ✅ | Fetches actual installed source code of npm/PyPI/crates/GitHub packages. Lets us READ the code at the locked version. |
| omc:document-specialist | OMC agent | ✅ | Internal repo docs lookup (Context Hub / `chub` when available, graceful web fallback). |
| WebFetch / WebSearch | built-in | 🟡 | Generic web. Use only when context7/opensrc/document-specialist don't cover. |

**Decision rule** (composed in `docs-best`):
1. "How do I use library X" / "what changed in version Y" → **plugin:context7**.
2. "How does function X actually work" / verify locked-version behavior → **opensrc** + `rg` or `cat` inside `$(opensrc path <pkg>)`.
3. Repo-internal architecture / design docs → **omc:document-specialist**.
4. Nothing else fits → **WebFetch** / **WebSearch**.

**Synergy:** context7 for API shape → opensrc to verify implementation in the version you're locked to.

---

## 5. Planning / orchestration / persistence loops

| Tool | Type | Status | Role |
|---|---|---|---|
| omc:autopilot | OMC skill | ✅ | Full autonomous: plan + parallel exec + verify until done. Default for broad asks. |
| omc:ralph | OMC skill | ✅ | Persistence loop — don't stop until verified. |
| omc:ultrawork (`ulw`) | OMC skill | ✅ | Maximum parallel execution. |
| omc:ralplan | OMC skill | ✅ | Iterative planning (Planner+Architect+Critic consensus). |
| omc:planner | OMC agent (opus) | ✅ | Strategic planning with interview. |
| omc:plan | OMC skill | ✅ | Start a planning session. |
| omc:deep-interview | OMC skill | ✅ | Socratic ambiguity gating before approval. |
| omc:deep-dive | OMC skill | ✅ | trace → deep-interview pipeline. |
| omc:team | OMC skill | ✅ | N coordinated agents on shared task list. |
| omc:omc-teams | OMC skill | ✅ | CLI workers in tmux panes. |
| omc:autoresearch | OMC skill | ✅ | Single-mission improvement loop with evaluator contract. |
| omc:ultragoal | OMC skill | ✅ | Multi-goal workflow with persisted ledger. |
| omc:ultraqa | OMC skill | ✅ | QA cycling: test/fix/repeat. |
| omc:sciomc | OMC skill | ✅ | Parallel scientist orchestration. |
| omc:ccg | OMC skill | ✅ | Codex/Claude/Gemini bridge. |
| omc:ask | OMC skill | ✅ | Ask other model providers. |
| autoexp | skill | 🟡 | Autonomous experimentation loop (generalized from Karpathy autoresearch). Different domain. |
| `loop` | built-in | 🟡 | Generic recurring task interval runner. |
| `schedule` | built-in | 🟡 | Cron remote agents (routines). |
| superpowers:writing-plans | skill | 🟡 | Plan-writing workflow. |
| superpowers:brainstorming | skill | 🟡 | Required before creative work. |
| `Plan` | built-in agent | 🟡 | Built-in architect agent. |

**Decision rule** (no composed skill yet — too high-frequency, OMC routes natively):
- Broad ambiguous build request → **omc:autopilot**.
- Specific known task with persistence requirement → **omc:ralph**.
- Many independent tasks → **omc:ultrawork**.
- Need consensus before execution → **omc:ralplan**.
- Need cron / scheduled → **`schedule`** (cloud) or **`loop`** (local interval).
- Need autonomous metric optimization loop → **autoexp**.
- Brainstorm a creative feature direction → **superpowers:brainstorming**.

---

## 6. Execution / coding agents

| Tool | Type | Status | Role |
|---|---|---|---|
| omc:executor / executor-low / executor-high | OMC agents (haiku/sonnet/opus) | ✅ | All code edits (single-file → multi-file). Path-policy delegates source-file edits here. |
| omc:architect / architect-low / architect-medium | OMC agents (opus) | ✅ | Architecture decisions, deep debugging, refactor design. |
| omc:debugger | OMC agent | ✅ | Root-cause analysis. |
| omc:tracer + omc:trace | OMC agent + skill | ✅ | Evidence-driven causal tracing with competing hypotheses. |
| omc:code-simplifier | OMC agent (opus) | ✅ | Simplify recently modified code. |
| feature-dev agents | plugin | ❌ removed | Replaced by OMC executor/architect/explore. |
| caveman:cavecrew-builder | agent | 🟡 | 1-2 file surgical edits in caveman mode. |
| caveman:cavecrew-investigator | agent | 🟡 | Read-only code locator in caveman mode. |
| `general-purpose` / `claude` | built-in agents | 🟡 | Fallback when nothing else fits. |

**Decision rule:**
- Multi-file refactor / complex change → **omc:executor-high** (opus).
- Standard feature → **omc:executor** (sonnet).
- One-line tweak → **omc:executor-low** (haiku) or direct edit if allowed path.
- Deep "why does this happen" → **omc:tracer** + **omc:debugger**.
- Architecture decision → **omc:architect**.

---

## 7. Search / explore

| Tool | Type | Status | Role |
|---|---|---|---|
| omc:explore / explore-medium | OMC agents (haiku/sonnet) | ✅ | Codebase exploration. |
| `Explore` | built-in agent | ✅ | Fast read-only locator. Quick/medium/very thorough breadth. |
| `osgrep` | plugin | ✅ | Fast structural code search. |
| `rg` (ripgrep) | CLI | ✅ | Raw grep — fastest. |
| codegraph-context | skill | 🟡 | Structural questions (callers/dead code/dep chains) — not content search. |
| ast-grep MCP | MCP (via OMC) | ✅ | AST-aware search/replace. |
| feature-dev:code-explorer | agent | ❌ removed | OMC explore covers. |
| caveman:cavecrew-investigator | agent | 🟡 | Caveman-mode locator. |

**Decision rule:**
- "Where is X defined?" → **`rg`** or **`Explore` quick**.
- "Trace this execution path" → **codegraph-context**.
- "AST rewrite all occurrences of pattern X" → **ast-grep MCP**.
- Broad exploration → **omc:explore** with model sized to scope.

---

## 8. Git / commits

| Tool | Type | Status | Role |
|---|---|---|---|
| omc:git-master | OMC agent | ✅ | Atomic commits, rebasing, history management. Style detection. |
| commit-commands plugin | plugin | ✅ | `/commit`, `/commit-push-pr` shortcuts. |
| caveman:caveman-commit | skill | 🟡 | Caveman-style commit messages. |
| git-reflog-recovery | skill | 🟡 | Specialty: recover lost work via reflog. |

**Decision rule:**
- Standard commit → **`/commit`** (commit-commands).
- Complex rebase/history rewrite → **omc:git-master**.
- Lost commits → **git-reflog-recovery**.

---

## 9. Test / verification

| Tool | Type | Status | Role |
|---|---|---|---|
| omc:test-engineer | OMC agent | ✅ | Test strategy, integration/e2e, flaky test hardening. |
| omc:tdd-guide / tdd-guide-low | OMC agents | ✅ | TDD workflow. |
| omc:qa-tester / qa-tester-high | OMC agents | ✅ | Interactive CLI testing via tmux. |
| omc:verify | OMC skill | ✅ | Verify a change really works. |
| omc:visual-verdict | OMC skill | ✅ | Visual verification. |
| superpowers:test-driven-development | skill | 🟡 | TDD discipline (rigid). |
| superpowers:verification-before-completion | skill | ✅ | Iron law: evidence before claims. |
| `verify` | built-in | ✅ | Run app + observe behavior. |
| proofshot | CLI | ✅ | Visual verification with PR artifacts. (See Browser domain.) |
| pr-review-toolkit:pr-test-analyzer | agent | ❌ removed | Replaced by omc:test-engineer + omc:verify. |

**Decision rule:**
- "Does this work in the real app?" → **`verify`** (built-in) or **proofshot** if visual.
- "Are the tests adequate?" → **omc:test-engineer**.
- "Don't claim done without evidence" → **superpowers:verification-before-completion** + **omc:verifier**.

---

## 10. Skill management / drift / cross-tool

| Tool | Type | Status | Role |
|---|---|---|---|
| skill-x (skill-sync / skill-compose / skill-audit) | npm + skills | ✅ | THIS overlay's substrate. Sync upstreams, compose derived skills, audit collection. |
| schema-drift | skill (ships with skill-x) | ✅ | Cross-layer schema drift detection. |
| code-drift | skill (ships with skill-x) | ✅ | Drift between code and upstream truth. Uses knip/lychee/ncu/gh. |
| mex | npm CLI | ✅ | Project memory scaffold + drift (memory-layer cousin of code-drift). |
| skill-creator | plugin + skill | ✅ | Authoring new skills. |
| oh-my-claudecode:learner | OMC skill | 🟡 | Extract a learned skill from current conversation. |
| oh-my-claudecode:skillify | OMC skill | 🟡 | Skill-ify recent work. |
| claudeception | skill | 🟡 | Continuous learning system / skill extractor. |
| oh-my-claudecode:self-improve | OMC skill | 🟡 | Self-improvement loop. |
| oh-my-claudecode:skill | OMC skill | ✅ | Local skill mgmt CLI. |
| skill-compose (skill-x) | tool | ✅ | Authoritative compose-from-N-parents. THIS REPO USES IT. |
| skill-sync (skill-x) | tool | ✅ | Authoritative upstream drift detector. |
| skill-audit (skill-x) | tool | ✅ | Authoritative collection auditor. |
| find-skills | skill (linked) | 🟡 | Discover/install skills from marketplaces. |

**Decision rule:**
- Add a new tool → **skill-audit** to surface overlaps → update FEATURE-MAP → if overlap, add to a `compose-rules/*.yaml` → **skill-compose** to regenerate SKILL.md.
- Upstream version drift (npm/docs/changelog) → **skill-sync**.
- Cross-layer schema drift → **schema-drift**.
- Code/repo drift → **code-drift** (skill-x) for code, **mex** for memory scaffold.
- Author a brand-new from-scratch skill → **skill-creator**.
- Extract a skill from THIS conversation → **omc:learner** (preferred over claudeception/skillify — picks the active session).

---

## 11. Security

| Tool | Type | Status | Role |
|---|---|---|---|
| computer-security | skill | ✅ | Machine security audit / scan / setup. |
| computer-security-review | skill | ✅ | Deep review reading Santa/LuLu/BlockBlock/TCC logs. |
| omc:security-reviewer / -low | OMC agents | ✅ | Code security review. |
| `security-review` | built-in | ✅ | Pending-changes security review. |
| security-guidance | plugin | ✅ | Security guidance plugin. |
| wazuh | skill | ✅ | Wazuh SIEM/XDR ops. |

**Decision rule:**
- Code in pending PR → **`security-review`** (built-in).
- Deep code security audit → **omc:security-reviewer**.
- Machine-level posture → **computer-security** + **computer-security-review**.
- SIEM/XDR ops → **wazuh**.

---

## 12. Compression / output style

| Tool | Type | Status | Role |
|---|---|---|---|
| caveman (mode skill) | skill | ✅ | Active mode — drops articles/filler. |
| caveman-compress | skill | ✅ | Compress markdown memory files. |
| humanizer | skill | 🟡 | Strip AI-tells from prose. Opposite job — for outward writing. |

---

## 13. Design / UI

| Tool | Type | Status | Role |
|---|---|---|---|
| omc:designer / -low / -high | OMC agents | ✅ | UI components, design systems. |
| frontend-design plugin | plugin | ✅ | Production-grade frontend skill. |
| omc:vision | OMC agent | ✅ | Analyze images/diagrams. |
| proofshot | CLI | ✅ | Visual verification. (See Browser domain.) |

---

## 14. Data / research / science

| Tool | Type | Status | Role |
|---|---|---|---|
| omc:scientist / -low / -high | OMC agents | ✅ | Data analysis / stats. |
| omc:autoresearch | OMC skill | ✅ | Stateful research loop. |
| autoexp | skill | ✅ | Karpathy-style metric-driven experimentation. |
| omc:sciomc | OMC skill | ✅ | Parallel scientist orchestration. |
| ragflow | skill | ⚠ scoped | Project-scoped to better-chatvote. |
| graphify | skill | ❌ removed | Replaced by ctx-mode + skill-x audit pipeline. |
| codegraph-context | skill | ✅ | Code structural analysis (also under Search). |

---

## 15. External services

| Service | Tools | Decision |
|---|---|---|
| GitHub | plugin:github MCP, `gh` CLI, commit-commands | `gh` CLI default; plugin:github MCP when staying in-context. |
| Notion | notion skill, claude.ai Notion MCP | claude.ai MCP for chat queries; notion skill for CLI ops. |
| Google (Gmail/Calendar/Drive) | gog skill, claude.ai Gmail/Calendar/Drive MCPs | gog skill canonical; claude.ai MCPs convenience. |
| Slack | claude.ai Slack MCP | Only path. |
| Sentry | sentry skill + claude.ai Sentry MCP auth | Skill canonical. |
| PostHog | posthog skill + claude.ai PostHog MCP auth | Skill canonical. |
| Vercel | vercel plugin + skill + `vercel` CLI | Plugin skills (`vercel:deploy`/`status`/`bootstrap`) canonical. Disable claude.ai Vercel MCP. |
| Linear | linear plugin | Only path. |
| HuggingFace | huggingface-skills plugin + huggingface skill | Plugin canonical. |
| ElevenLabs | elevenlabs skill | Only path. |
| Lumin | lumin skill + claude.ai Lumin MCP | Skill canonical. |
| Excalidraw | claude.ai Excalidraw MCP | Only path. |
| Mermaid | claude.ai Mermaid MCP | Only path. |
| Canva | claude.ai Canva MCP | Only path. |
| Apollo.io | claude.ai Apollo MCP | Only path. |
| PayPal | claude.ai PayPal MCP | Only path. |
| n8n | claude.ai n8n MCP | Only path. |
| DirectBooker | claude.ai DirectBooker MCP | Only path. |
| Three.js viewer | claude.ai Three.js MCP | Only path. |

---

## 16. Quick-fix / domain skills (no overlap)

These are point fixes for specific known bugs. No decision rule needed; trigger if their description matches.

`agent-browser-apple-silicon-setup`, `better-auth-updateuser-limitations`, `convex-action-responsiveness`, `convex-canary-preview-mirror`, `convex-prod-to-dev-sync`, `gpu-to-cpu-physics-react-port`, `playwright-bdd-convex-parallel-tests`, `po-merge-conflict-resolver`, `react-compiler-tanstack-table`, `react-hook-form-nested-persistence`, `react-hook-object-dependency-memoization`, `react-pdf-indesign-replication`, `remotion-headless-google-fonts-fix`, `rhf-array-setvalue-reactivity`, `sql-dump-json-parsing`, `suspicious-round-values-pagination`, `tailwind-v4-vercel-oxide-scanner-fix`, `threejs-physics-nan-coordinate-normalization`, `vite-express-tailscale-cors`, `wxt-playwright-extension-testing`, `zsh-slow-startup-diagnosis`, `k8s-service-debug`, `h-reason`.

---

## Update policy

- **Add a tool**: append to its domain row + run `npm run audit`.
- **Remove a tool**: strike row, set status `❌`, update decision rule.
- **Change a decision rule**: edit the rule line + bump the matching `compose-rules/*.yaml` + regenerate the composed SKILL.md.
- **Sync drift**: `bash scripts/update.sh` runs `skill-sync`; any composed skill whose parent moved gets queued for recompose.

The audit script (`npm run audit`, delegates to skill-x `audit.mjs`) parses this file's tables and cross-checks against `~/.claude/skills/`, `~/.claude/plugins/installed_plugins.json`, and `npm ls -g` to flag drift between what's mapped here and what's actually installed.

#!/usr/bin/env node
// sync-parents.mjs — read sync.config.json, run each parent's structured
// `cmd`+`args` check, hash the output, compare to manifest/<parent>.json, report drift.
//
// Uses execFileSync (no shell) and an allowedCmds whitelist to avoid command injection.
//
// Usage:
//   node scripts/sync-parents.mjs            # check + write manifest
//   node scripts/sync-parents.mjs --report   # check, do not write
//   node scripts/sync-parents.mjs --quiet    # suppress per-parent log lines
//   node scripts/sync-parents.mjs --check    # exit 1 if any drift (CI)

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { argv, exit } from "node:process";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const CONFIG_PATH = join(ROOT, "sync.config.json");
const MANIFEST_DIR = join(ROOT, "manifest");
const SKILLS_DIR = join(ROOT, "skills");

const flags = new Set(argv.slice(2));
const REPORT_ONLY = flags.has("--report");
const QUIET = flags.has("--quiet");
const STRICT = flags.has("--check");

const log = (...x) => {
  if (!QUIET) console.log(...x);
};

const sha = (s) => createHash("sha256").update(s).digest("hex").slice(0, 16);

const config = JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
const allowed = new Set(config.allowedCmds || []);
if (!existsSync(MANIFEST_DIR)) mkdirSync(MANIFEST_DIR, { recursive: true });

const runCheck = (cmd, args) => {
  if (!allowed.has(cmd)) {
    return { ok: false, reason: `cmd "${cmd}" not in allowedCmds` };
  }
  if (!Array.isArray(args) || args.some((a) => typeof a !== "string")) {
    return { ok: false, reason: "args must be an array of strings" };
  }
  try {
    const out = execFileSync(cmd, args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 15000,
    }).trim();
    return { ok: true, out };
  } catch (err) {
    return { ok: false, reason: `check failed: ${err.code || err.message}` };
  }
};

let drifted = 0;
let stable = 0;
let skipped = 0;
const driftedNames = [];

for (const [name, spec] of Object.entries(config.parents || {})) {
  if (!spec.cmd) {
    skipped++;
    log(`  -  ${name} (no cmd, kind=${spec.kind})`);
    continue;
  }
  const result = runCheck(spec.cmd, spec.args || []);
  if (!result.ok) {
    skipped++;
    log(`  ?  ${name} (${result.reason})`);
    continue;
  }
  const hash = sha(result.out);
  const manifestPath = join(MANIFEST_DIR, `${name}.json`);
  const prior = existsSync(manifestPath)
    ? JSON.parse(readFileSync(manifestPath, "utf8"))
    : null;

  const next = {
    name,
    kind: spec.kind,
    cmd: spec.cmd,
    args: spec.args,
    value: result.out,
    hash,
    checkedAt: new Date().toISOString(),
  };

  if (prior && prior.hash === hash) {
    stable++;
    log(`  =  ${name} (${result.out})`);
  } else {
    drifted++;
    driftedNames.push(name);
    const from = prior ? `${prior.value} → ` : "(new) ";
    log(`  *  ${name} ${from}${result.out}  [DRIFT]`);
  }

  if (!REPORT_ONLY) {
    writeFileSync(manifestPath, `${JSON.stringify(next, null, 2)}\n`);
  }
}

log("");
log(`drift: ${drifted}  stable: ${stable}  skipped: ${skipped}`);

if (drifted > 0 && existsSync(SKILLS_DIR)) {
  log("");
  log("Composed skills that may need re-composition:");
  for (const entry of readdirSync(SKILLS_DIR, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const skillPath = join(SKILLS_DIR, entry.name, "SKILL.md");
    if (!existsSync(skillPath)) continue;
    const body = readFileSync(skillPath, "utf8");
    if (driftedNames.some((p) => body.includes(p))) {
      log(`  - skills/${entry.name}/SKILL.md`);
    }
  }
}

exit(STRICT && drifted > 0 ? 1 : 0);

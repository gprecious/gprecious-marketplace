# Codex Profile

How to shape a goal prompt for **OpenAI Codex** (the Codex CLI / cloud software-engineering agent).

## Who Codex is, and what that implies

Codex rewards a complete, self-contained task description and runs hands-off for longer than a conversational agent. Its loop is less chatty — you write a clear, full spec or you get poor results. It retains long-range instructions well and produces terse output. Design around this: **freeze everything the agent needs upfront**, give it explicit verification commands, and let it run.

## Prompt structure — the official four-part frame

Codex's official framework is **Goal / Context / Constraints / Done-when** (add **Inputs** when data shapes matter):

```
Goal: <one sentence — the outcome that defines "done">

Context: <files and paths that matter, environment, existing conventions to follow.
Reference paths rather than pasting whole files.>

Inputs: <data shapes / types / formats, if relevant>

Constraints: <no new deps; keep the existing API; perf/security/naming rules; what not to touch>

Done when: <measurable pass/fail — tests pass, bug no longer reproduces, metric threshold met>

Verify: <exact commands to run — e.g. `npm run typecheck && npm test` — and confirm they pass.
Plan before coding, then implement, then run the checks yourself. Keep the diff minimal.>
```

## Codex features to weave in (when they fit)

- **`/goal` (long-horizon autonomy)** — Codex has a real `/goal` command (experimental; enabled via `[features] goals = true` in `config.toml`). Use it for multi-hour, unattended grinds (migrations, repo-wide refactors, eval-optimization loops). The goal text is *both* the directive and the completion criteria, so make the stopping condition verifiable. Syntax:
  > `/goal Complete <objective> without stopping until <verifiable end state>.`
  >
  > Example: `/goal Replace all Moment.js usage with date-fns repo-wide without stopping until `rg "from 'moment'"` returns nothing and `npm run typecheck` and `npm test` both pass. After each module, run the suite, fix failures, and commit per module with a minimal diff.`
  >
  > The objective is hard-capped at **4000 characters** (`MAX_THREAD_GOAL_OBJECTIVE_CHARS`) — Codex rejects longer input outright (*"Goal objective is too long: N characters. Limit: 4000"*), before the run starts. Codex even tells you the fix: move long instructions into a file and reference it — e.g. `/goal Follow the instructions in docs/goal.md; stop when the test suite passes.` Keep the objective itself to the verifiable end state and its check commands, and let the file carry the detail.
- **Plan mode (`/plan`)** — for ambiguous work, have Codex gather context and clarify before implementing.
- **Reasoning effort** — the single biggest quality lever. Suggest `medium` for routine interactive work, `high`/`xhigh` for hard, multi-step, or multi-hour problems. Mention it when the task warrants it.
- **AGENTS.md (durable vs one-off)** — keep the *immediate* objective in the prompt; recommend moving *durable, reusable* rules (build/test/lint commands, repo conventions, standing safety constraints) into `AGENTS.md` so every future prompt stays focused. If the user's requirement contains standing rules ("we always use pnpm", "never touch the generated/ dir"), note that those belong in AGENTS.md rather than re-stated each time.
- **Output contract** — ask for working code (not just a plan), referenced file paths instead of dumped files, and a minimal diff with tests.

## Before → after

**A — performance task**
- Before: *"make the dashboard faster"*
- After:
  > Goal: Reduce dashboard load time on the metrics route.
  > Context: `src/pages/Dashboard.tsx`, `src/api/metrics.ts`.
  > Constraints: No new dependencies; keep the existing query API.
  > Done when: Lighthouse time-to-interactive < 1s on the metrics route and `npm test` passes.
  > Verify: Plan before coding, then implement, then run the Lighthouse check and `npm test` yourself and report both. Reasoning effort: high.

**B — long-horizon migration (uses `/goal`)**
- Before: *"migrate us off Moment.js"*
- After:
  > `/goal Replace all Moment.js usage with date-fns across the repo without stopping until: (1) `rg "from 'moment'"` returns no results, (2) `npm run typecheck` and `npm test` both pass. After each module: run the test suite, fix failures, keep diffs minimal, and commit per module.`

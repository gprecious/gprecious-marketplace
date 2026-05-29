# Claude Code Profile

How to shape a goal prompt for **Claude Code** (Anthropic's CLI coding agent).

## Who Claude Code is, and what that implies

Claude Code explores the repository before acting, proposes plans, checkpoints, and adapts to your existing patterns well. Its two quirks to design around:

1. **It is eager to act on ambiguous input** — it can treat a neutral question as an edit request, or start coding before it understands the problem. Counter with an explicit scope boundary and, for anything multi-file, a plan-first framing.
2. **It stops when the work *looks* done** — so the prompt must carry a verifiable end state and a check it can run itself.

## Prompt structure

Assemble the prompt in roughly this order. Omit a section only when it genuinely doesn't apply.

```
<Goal — the verifiable end state, one or two sentences>

Context:
- Read @path/to/relevant/file and @path/to/pattern/example
- <data shapes, existing conventions, sources, screenshots>

Approach:
- <For multi-file work: explore and propose a plan before editing.>
- Follow the pattern in @<example file>; build from scratch without new libraries unless one is already in the codebase.

Constraints / out of scope:
- Only touch <these files/areas>. Do not change <X>.
- <perf / security / style rules>

Acceptance criteria:
- <concrete input→output examples, e.g. "user@example.com → valid, "abc" → invalid">
- <a command that must pass>

Verification:
- Run <exact command, e.g. `npm test`> and fix failures. Show me the passing output.
- Address the root cause; don't suppress errors or weaken the test to pass.
```

## Claude Code features to weave in (when they fit)

- **`@file` references** — anchor context to real files instead of describing them. The agent fetches what it needs.
- **Plan mode** — for multi-file or ambiguous work, tell it to explore and produce a plan *before* editing. Reviewing a plan is higher-leverage than reviewing a diff.
- **Thinking triggers** — add `think` / `think hard` / `ultrathink` (escalating reasoning budget) for genuinely hard tasks: 5+ files, security-sensitive, or multiple candidate root causes. Don't add it to routine changes.
- **`/goal <condition>`** — for long-horizon, mostly-unattended work. Sets a session-scoped completion condition that a fast model re-checks after every turn until it holds. Use it when the task is a sustained grind (a migration, an optimization loop) rather than a single change. Make the condition measurable and bound it. Example:
  > `/goal All callers migrated off the legacy `parseDate` helper, `npm run typecheck` and `npm test` both pass, or stop after 25 turns.`
- **Subagents** — suggest a fresh-context subagent for adversarial review ("review the diff against the plan; report correctness and requirement gaps, not style") or for scoped exploration that would otherwise flood the main context.
- **Evidence over assertions** — ask it to show the command it ran and the output, not just claim success.

## Scope guards (Claude Code-specific)

Because Claude Code acts eagerly, add an explicit guard when the user's intent is investigation or a tightly-bounded change:

- For a question, not a task: "This is a question — explain, don't edit any files."
- For a bounded change: "Change only `<file>`. If you think other files need changing, stop and tell me first."

## Before → after

**A — feature request**
- Before: *"add a calendar widget"*
- After:
  > Implement a calendar widget on the home page that lets the user pick a month and paginate forward/back to choose a year. Look at @components/HotDogWidget.tsx — follow that pattern and build from scratch without adding libraries beyond what's already in the codebase. Only add files under `components/calendar/` and wire it into @pages/Home.tsx. Done when the widget renders, month/year selection updates the bound state, and `npm test` passes. Run the tests and show the output.

**B — bug fix**
- Before: *"fix the login bug"*
- After:
  > Users report login fails after a session timeout. Explore the auth flow in @src/auth/ (token refresh especially) and propose the fix before editing. Write a failing test that reproduces the timeout case first, then make it pass. Address the root cause — don't suppress the error or loosen the test. Change only files under `src/auth/`; if anything else needs touching, stop and tell me. Show the failing-then-passing test output.

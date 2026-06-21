---
name: loopcraft
description: Convert a recurring or repetitive task description into a Claude Code /loop prompt — the loop sibling of goalcraft. 반복·주기적 작업 설명을 Claude Code /loop 용 프롬프트로 변환한다(goalcraft의 loop 형제). Use when the user wants a task shaped into a /loop prompt — "루프 프롬프트로 만들어줘", "/loop 용으로", "주기적으로 반복하게", "매 N분마다 ~", "~까지 반복해서", "이거 loop으로 돌려줘" — or mentions the /loop command, recurring/scheduled in-session execution, or babysitting/polling a long-running thing. Picks the mode (fixed interval → cron, self-paced → model self-paces, or loop.md default) and bakes in an objective stop condition, an iteration ceiling, and a verification check. Proactively fire on recurring-execution requests ("배포 끝날 때까지 확인", "CI 통과할 때까지 반복", "keep checking the deploy"). Not for single-shot tasks (→ goalcraft), running the loop yourself, deciding whether something should be a loop or auditing loop governance (→ loop-engineering), translating, or explaining /loop.
---

# Loopcraft — Requirements → Claude Code /loop Prompt

A coding agent stops when the work *looks* done. In a one-shot task that costs you one wasted run; in a **loop** it costs you a runaway — the agent re-declares victory every iteration, or never stops at all. A good `/loop` prompt replaces you as the stop signal: it carries an *objective* termination condition the agent can check itself, a ceiling so it can't spin forever, and a verification sensor so each iteration produces evidence rather than a vibe.

This skill takes whatever the user gives you — "keep an eye on the deploy", "fix CI until it's green", "babysit this PR" — and rebuilds it into a prompt tuned for Claude Code's `/loop`. It is **Claude Code-specific**: `/loop` is a Claude Code built-in and has no Codex equivalent.

**Boundary (route, don't overreach):** a *single* run → **goalcraft**. *Whether* a task should be a loop, plus its 5-element governance and audit → **loop-engineering**. The repeating `/loop` prompt itself → here.

## Step 1 — Identify the loop mode

`/loop` behaves three ways depending on what you give it. Pick the mode first; everything else follows from it.

| Mode | When | Shape |
| --- | --- | --- |
| **fixed-interval** | Regular polling on a clock — "every 5 min", "after each deploy", a cadence the user named | `/loop 5m <task>` → converted to cron |
| **self-paced** | A convergent task with a real finish line — "until CI is green and reviews are resolved" | `/loop <task>` (interval omitted) → Claude picks a 1min–1h delay each iteration and **ends the loop itself once the task is provably complete** |
| **loop.md-default** | Standing branch/PR maintenance you'd re-run with a bare `/loop` | `.claude/loop.md` body (a default prompt, reloaded every iteration) |

How `/loop` parses the line (mirror this when you choose): a leading bare token matching `^\d+[smhd]$` (e.g. `30m`) **or** a trailing "every …" clause becomes the interval; with no interval it is self-paced. Units are `s/m/h/d`; seconds round up to a minute; intervals that don't map to a clean cron step (`7m`, `90m`) are rounded and Claude says what it picked. A recurring loop self-expires after **7 days**.

If the user's intent spans more than one of these, ask which cadence they want (Step 3) rather than guessing.

## Step 2 — Extract the loop skeleton

Pull these five fields out of the request. Most will be implicit or missing — that's expected; Step 3 fills them.

- **cadence** — the interval (fixed mode) or the self-paced finish line. This is the Step 1 decision made concrete.
- **task** — the *one* focused job to do each iteration. If the request bundles several, split it and say so; mega-loops degrade fast.
- **state / context** — how each iteration sees the last one's work: git history, files written, `@file` references, a checklist in a tracked file. Without this the loop redoes work it already did.
- **verification** — the objective sensor that says an iteration actually progressed: a test exit code, `lint`/`typecheck`, zero console errors, a diff, a build. Not "looks fixed".
- **stop** — the done-criterion *plus* a ceiling. The done-criterion must be checkable; the ceiling bounds runaway.

## Step 3 — Fill the gaps: ask before converting

A loop prompt is only as safe as its stop condition, and the user almost never supplies one. Before producing the prompt, scan for missing or vague fields and ask targeted questions (use `AskUserQuestion` if available; otherwise a short numbered list). Prioritize, in order:

1. **Objective stop condition** — the most common and most dangerous gap. "Until it's good" is not checkable; the loop never ends or ends arbitrarily. Push for a signal: "CI green AND zero unresolved review threads", "no TODO markers remain", "endpoint returns 200".
2. **Iteration ceiling / budget** — even with a good stop condition, cap it (default: start at ~50 iterations, or a wall-clock/cost budget). Self-paced loops carry the highest runaway risk.
3. **Verification command** — exactly how each iteration proves progress (`npm test`, `pnpm lint && tsc`, a smoke check).
4. **Interval value** — only for fixed mode: how often.

Ask only for what is genuinely missing *and* would change the output. If the user said "just convert it, don't ask", make reasonable assumptions and state them explicitly under the output so they stay visible and correctable. One round of questions is far cheaper than a runaway loop.

If, while doing this, you realize the task is actually a **single run** (no repetition, one finish), stop and route to **goalcraft** instead of forcing a loop.

## Step 4 — Build from the mode profile

Read the matching section of `references/loop-modes.md` and assemble the prompt:

- fixed-interval → the `## fixed-interval` profile
- self-paced → the `## self-paced` profile
- loop.md-default → the `## loop.md-default` profile

`references/recipes.md` has the stop-condition sentence templates and worked few-shot examples — pull the closest one as a starting shape.

## Step 5 — Deliver

Output the finished artifact inside a **single fenced code block** so the user can paste it straight in. Above the block, one short line naming the mode (e.g. `고정 5분 폴링:` / `self-paced (간격 생략):` / `.claude/loop.md:`). For `loop.md` mode the block is the file body; for the other two it's the `/loop …` command line.

If you made assumptions — because the user said don't ask, or the input was thin — list them in one or two bullets *under* the block.

## Always-on rules (apply to every loop prompt, regardless of mode)

These come straight from the validated loop-engineering literature (Loop Library, requesty, ralph completion-promise, research-engine evolve). Bake them in even when the user didn't ask:

1. **Objective stop, never subjective.** Forbid "until it's satisfactory". For self-paced, name the *provably complete* signal that lets `/loop` end itself. Use the templates: *"Stop when X, progress stalls, or the budget ends"* / *"Continue until no Y remains or the limit is reached"*.
2. **Always set a ceiling.** Iteration cap, wall-clock, or cost budget — plus a no-progress stop ("if an iteration changes nothing, stop and report").
3. **Verification every iteration.** Each change must show evidence (command + output), not a claim. Kills the "declared done after checking half of it" failure mode.
4. **Reference prior state.** Tell the loop to read the last iteration's result (git/files) before acting, so it doesn't repeat work.
5. **Human gate on high-risk steps.** Push, merge, deploy, or production-data changes get an explicit "stop and ask before doing X" — analysis is the agent's, the decision is the human's. (Aligns with loop-engineering's 5 elements.)
6. **No single-trial verdicts on noisy work.** If "better" is subjective (quality, taste, LLM-judged), require a rubric + threshold or repeated measurement before the loop concludes — don't let one good-looking iteration end it.

And the cross-cutting prompt-craft rules: **one focused job per iteration**, **show don't describe** (one concrete example beats a paragraph), **lead with the executable verification command**, **prefer positive instructions** over "don't".

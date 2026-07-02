# Loop Mode Profiles

How to shape a `/loop` prompt for each of the three modes. Pick the mode in Step 1, then build from the matching section here. The before→after examples show the transform; copy their *shape*, not their wording.

---

## fixed-interval

A clock-driven loop: the same prompt fires on a cron cadence while the session is open.

**Shape:** `/loop <N>[smhd] <task>` — the interval can lead as a bare token (`30m …`) or trail as a clause (`… every 2 hours`). Units `s/m/h/d`; seconds round up to a minute; off-grid intervals (`7m`, `90m`) are rounded to a clean cron step and Claude tells you which. You can also loop a saved command: `/loop 20m /review-pr 1234`.

**How it ends:** it doesn't, on its own — it runs until the user presses `Esc` or **7 days** elapse (recurring self-expiry). So the *value* has to come from each tick being cheap and honest:

- Make the task **no-op-friendly**: "…; if nothing changed, say so in one line." A loop that writes a paragraph every 5 minutes is noise; one that reports "still building" in a line is signal. (no-op precision is the metric that matters here.)
- Don't bury irreversible actions in a fixed tick. Pushing/deploying on a timer needs a **human gate** (see rule 5) unless the user explicitly authorized unattended action.

**Guardrails to bake in:** a meaningful cadence (don't poll a 10-minute build every 30s); a one-line no-progress report; an explicit note if the loop may take a destructive action.

**Before → after**
- Before: *"keep checking if the deploy is done"*
- After:
  > `/loop 2m Check whether the prod deploy finished. If it's still running, reply in one line with the current stage. If it finished, summarize the result (success/failure, duration) and tell me to stop the loop. Don't trigger or modify the deploy.`

---

## self-paced

No interval: Claude chooses a delay (1 min–1 h) after each iteration based on what it saw — short while a build is finishing, longer when things are quiet — and **ends the loop itself by not scheduling the next wakeup once the task is provably complete**. This is the mode for convergent work with a real finish line, and it carries the **highest runaway risk**, so the stop condition and ceiling are non-negotiable.

**Shape:** `/loop <task>` with the task carrying (a) the objective done-signal and (b) the ceiling, stated in the prompt itself.

**Use the Monitor tool when polling a stream:** if the task is "watch this log/build", say so — Claude can run a background script and stream lines instead of re-running a prompt, which is more responsive and token-efficient than interval polling.

**Stop condition — make it checkable:** convert any "until it's good" into a signal the agent reads from the environment. Templates:
- *"Continue until `<command>` exits 0 and there are no unresolved review threads, or after 25 iterations."*
- *"Stop when no failing tests remain, progress stalls for two iterations, or the budget is spent."*

**Guardrails to bake in:** an iteration ceiling (start ~50, lower for expensive tasks); a no-progress stop; verification (test/lint/build) named explicitly; "read the previous iteration's diff/result before acting" so it doesn't loop on the same change.

**Before → after**
- Before: *"fix CI until it passes"*
- After:
  > `/loop Get CI green on this branch. Each iteration: read the latest failing job log, fix the root cause (don't weaken tests), push, and wait for the run. Continue until the CI run is green AND there are no unresolved review comments, progress stalls for two iterations, or after 20 iterations — then stop and summarize. Show the failing-then-passing job status each time. Don't merge; stop and ask before merging.`

---

## loop.md-default

A `loop.md` file replaces the bare-`/loop` maintenance prompt with your own default. Use it for *standing* upkeep the user would otherwise re-type every time.

**Shape:** write the file body (plain Markdown, no required structure — write it as if typing the `/loop` prompt directly). Locations, first one wins:
- `.claude/loop.md` — project-level (takes precedence)
- `~/.claude/loop.md` — user-level (any project without its own)

It's reloaded **every iteration** (edit while running to refine), and content past **25 KB** is truncated, so keep it tight. A bare `/loop` then runs this at a dynamically chosen interval; `/loop 15m` runs it on a fixed one.

**What it replaces:** without `loop.md`, bare `/loop` runs Claude Code's built-in maintenance prompt — continue unfinished work → tend the current branch's PR (review comments, failed CI, merge conflicts) → cleanup passes (bug hunt, simplify) — and only takes irreversible actions the transcript already authorized. Your `loop.md` should keep that same conservative spirit: bounded scope, evidence each pass, no new initiatives.

**Stop condition:** each pass is self-bounding (it does the available upkeep and reports), so "stop" is the user pressing `Esc`. Still tell each pass to **report-and-rest when there's nothing to do** rather than inventing work.

**Before → after** (`.claude/loop.md` body)
- Before: *"keep the release branch healthy"*
- After:
  > ```
  > Check the `release/next` PR. If CI is red, pull the failing job log, diagnose, and
  > push a minimal fix addressing the root cause. If new review comments arrived, address
  > each and resolve the thread. Do not merge or force-push. If everything is green and
  > quiet, say so in one line and do nothing else.
  > ```

---

> **Not a `/loop` mode: `/goal`.** "Keep working until this condition holds" (no interval, no re-check delay) is Claude Code's `/goal`, which **goalcraft** owns — see its `references/claude-code.md`. Route those requests there; loopcraft stays `/loop`-only.

# Stop-Condition Patterns, Recipes & Anti-Patterns

Pull the closest recipe as a starting shape, then specialize it. Every recipe already carries an objective stop, a ceiling, and a verification sensor — keep all three when you adapt it.

## Stop-condition sentence templates

Two patterns cover almost every loop. Default to one of them:

- **Stop-when:** *"Stop when `<objective signal>`, progress stalls for N iterations, or the budget/ceiling is reached."*
- **Continue-until:** *"Continue until no `<problem type>` remains, or after N iterations."*

The signal must be something the agent reads from the environment — an exit code, a count reaching zero, a status flipping — never "until it looks right". And per the ralph `completion-promise` rule: **the agent may declare done only when the statement is unequivocally true; it must not fake completion to escape the loop.** Put that obligation in the prompt for self-paced loops.

## Recipes (개발 맥락 few-shot)

Each is `input (거친 요구) → output`. The mode label tells you which `loop-modes.md` profile it came from.

**1. docs-drift-sweep** — *"코드 바뀐 거 따라서 CLAUDE.md/README 계속 맞춰줘"* · self-paced
> `/loop Reconcile the docs with the code. Each iteration: diff CLAUDE.md and README against the current source, fix the next concrete drift you find (stale path, removed flag, wrong command), and note what you changed. Continue until a full pass finds no drift, or after 15 iterations. Don't rewrite for style — only fix factual mismatches. Show the diff each iteration.`

**2. lint-type-sweep** — *"린트랑 타입 에러 0 될 때까지 돌려"* · self-paced
> `/loop Drive `pnpm lint` and `tsc --noEmit` to zero errors on this branch. Each iteration: run both, fix the root cause of the next cluster of errors (don't disable rules or add `any`), and re-run. Continue until both commands exit 0, progress stalls for two iterations, or after 25 iterations. Show the error count before/after each pass.`

**3. e2e-healer** — *"CI에서 e2e 깨지면 고쳐서 초록 만들어줘"* · self-paced
> `/loop Heal the failing e2e suite. Each iteration: read the latest Playwright trace for the first failing spec, fix the root cause in app or test (whichever is actually wrong), and re-run that spec. Continue until the full e2e run is green, or after 20 iterations — then stop and summarize what was broken. Don't mark specs `.skip` to pass. Show the failing-then-passing run.`

**4. preview-error-sweep** — *"프리뷰 배포되면 콘솔 에러 점검"* · fixed-interval
> `/loop 10m Open the latest preview URL, check the browser console and network panel. If there are zero errors and the smoke route returns 200, reply in one line "preview clean". If there are errors, list them with the failing request/stack — but don't push a fix, just report. Stop me when it's been clean twice in a row.`

**5. pr-babysit** — *"이 브랜치 PR 머지될 때까지 계속 봐줘"* · self-paced
> `/loop Babysit this PR to merge-ready. Each iteration: address new review comments (resolve the thread), pull and fix any failing CI job at the root cause, and resolve merge conflicts. Continue until CI is green, all review threads are resolved, and there are no conflicts — or after 15 iterations. Do not merge; stop and ask once it's merge-ready. Show CI status each pass.`

**6. dep-bump-check** — *"의존성 업데이트 있나 매일 한 번 확인"* · fixed-interval
> `/loop 1d Check for outdated dependencies with the project's package manager. If everything is current, say so in one line. If updates exist, list them grouped by major/minor/patch with changelog links — but don't modify any lockfile or open a PR. Flag any with known advisories.`

## Anti-patterns (catch these in the input and fix them)

| Anti-pattern | Why it breaks | Fix |
| --- | --- | --- |
| "…until it's good / satisfactory" | No checkable signal — loop never ends or ends arbitrarily | Replace with an exit code, a zero-count, a status flip |
| No ceiling | One bad iteration → runaway cost; "start with 50" never set | Add iteration cap + no-progress stop |
| "looks fixed" / no verification | Agent declares done after checking half the surface | Name the exact command whose output is the evidence |
| Irreversible action on a timer | Fixed-interval push/deploy with no gate | Add a human gate, or make the tick report-only |
| Subjective "better" judged once | One lucky iteration ends a quality loop (Goodhart) | Rubric + threshold, or repeated measurement before concluding |
| Mega-loop (several jobs per tick) | Quality degrades, hard to verify | One focused job per iteration; split the rest into separate loops |

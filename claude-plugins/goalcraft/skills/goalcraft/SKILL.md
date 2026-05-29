---
name: goalcraft
description: Convert raw feature requirements, bug reports, or rough task descriptions into a goal-optimized prompt for the agentic coding tool that will run it — Claude Code or OpenAI Codex. 거친 요구사항·버그 리포트·대충 적은 작업 설명을, 그 작업을 실제로 실행할 코딩 에이전트(Claude Code 또는 Codex)에 맞춘 goal 최적화 프롬프트로 변환한다. Use when the user wants a requirement shaped into a prompt/spec/goal for an agent — "이거 프롬프트로 만들어줘 / 변환해줘", "코덱스(codex)/클로드코드용으로", "목표·범위·완료조건 갖춘 프롬프트로" — or mentions the goal feature or /goal command. By default targets the agent running the skill (Claude Code → Claude-optimized, Codex → Codex-optimized); honors an explicit named target. Proactively fire on vague requirements headed to a coding agent ("대시보드 빠르게 해줘", "add auth", "로그인 버그 고쳐줘"). Not for implementing/debugging it yourself, codex code review, explaining /goal, translating, editing AGENTS.md, multi-agent orchestration (cmux/herdr), or writing a plan.
---

# Goalcraft — Requirements → Goal-Optimized Agent Prompt

Coding agents stop when the work *looks* done. A good prompt replaces you as the stop signal by giving the agent a measurable goal it can verify on its own. This skill takes whatever the user gives you — a feature idea, a bug report, a one-liner — and rebuilds it into a prompt tuned for the specific agent that will execute it.

The same goal lands differently in each tool, so this skill is **executor-adaptive**: it produces a Claude Code-optimized prompt when Claude Code runs it, and a Codex-optimized prompt when Codex runs it. Both tools have a real `/goal` command for long-horizon autonomous work; this skill knows when to invoke it.

## Step 1 — Identify the target agent

The target is **the agent executing this skill**, unless the user says otherwise.

- You are **Claude Code** (Anthropic) → use the `references/claude-code.md` profile.
- You are **OpenAI Codex** → use the `references/codex.md` profile.
- **Explicit override wins:** if the user named a target — "codex 용으로", "for claude code", "this is going to Codex", "make it for the other agent" — build for the named target regardless of who is running.
- If you genuinely can't tell which agent you are and the user didn't say, ask once, briefly.

Why it matters: Claude Code is conversational, explores the repo before acting, and is *eager to act on ambiguous input* — so it needs explicit scope guards and a plan-first framing. Codex rewards a dense, self-contained spec and runs autonomously for longer — so it needs everything frozen upfront and verification commands baked in.

## Step 2 — Extract the goal skeleton

Every strong agent goal, in either tool, decomposes into the same five fields. Pull them out of whatever the user gave you (much of it will be implicit or missing — that's expected):

- **Objective / done-state** — the verifiable *end state*, phrased as an outcome, not an activity. "Login survives a session timeout and a regression test passes," not "fix the login bug."
- **Context** — the files, modules, data shapes, existing patterns to follow, and sources to read. Use repo-native references (`@file` in Claude Code, explicit file paths in Codex).
- **Constraints** — what must NOT change, libraries to use or avoid, perf/security/style rules, scope boundaries.
- **Acceptance criteria (done-when)** — concrete pass/fail signals: example input→output pairs, a command that must exit 0, a metric threshold.
- **Verification** — the check the agent runs *itself* (tests, build, lint, screenshot diff) to close the loop.

These five come straight from both vendors' official guidance — Anthropic's Claude Code best practices and OpenAI's `Goal / Context / Constraints / Done-when` framework.

## Step 3 — Fill the gaps: ask before converting

A goal prompt is only as strong as its weakest field, and the user almost never supplies all five. Before producing the prompt, scan for missing or vague fields and **ask the user targeted questions** (use `AskUserQuestion` if available; otherwise a short numbered list). Prioritize, in order:

1. **Acceptance criteria / done-when** — the most common and most damaging gap. Without a measurable "done", the agent declares victory early and you become the verification loop.
2. **Scope / out-of-scope** — which files or areas are in play, what must stay untouched.
3. **Constraints** — libraries, patterns to follow, perf/security rules.
4. **Verification command** — exactly how success is checked (`npm test`, `cargo build`, a repro script).

Ask only for what is genuinely missing *and* would change the output — don't interrogate. If the user already gave enough, skip straight to conversion. If the user says "just convert it, don't ask", respect that and instead make reasonable assumptions, stated explicitly under the output so they're visible and correctable.

Why ask: one round of clarifying questions is far cheaper than a wrong autonomous run. A vague requirement like "make the dashboard better" has no pass/fail signal at all — the agent cannot know when to stop.

## Step 4 — Build the prompt from the target profile

Read the matching profile and assemble the prompt:

- Claude Code → `references/claude-code.md`
- Codex → `references/codex.md`

Both profiles share these cross-cutting rules — apply them always, regardless of target:

- **Define "done" as something the agent can test**, not a feeling. A pass/fail signal is what lets it self-iterate.
- **Show, don't describe.** One concrete example — an input→output pair, or a snippet of the desired code style — beats a paragraph of description. (Echoed by GitHub's study of 2,500+ repos.)
- **Prefer positive instructions** ("do X") over negative ("don't do Y"). Negatives raise the probability the model does the very thing you forbade; reframe as what TO do where you can.
- **Lead with executable commands** — the exact test/build/lint invocation. It proves the check exists and anchors the agent's verification behavior.
- **One focused goal per prompt.** If the request spans several independent changes, decompose it and say so; mega-prompts produce lower-quality output than bounded tasks.
- **Surface edge cases explicitly.** Models default to the happy path; name the cases that matter.

## Step 5 — Deliver

Output the finished prompt inside a **single fenced code block** so the user can copy-paste it straight into the target agent. Above the block, one short line naming the target (e.g. `Claude Code 용:` / `Codex 용:`). Add nothing else unless the user asked for rationale.

If you made assumptions — because the user said don't ask, or the input was thin — list them in one or two bullet lines *under* the block so they stay visible and easy to correct.

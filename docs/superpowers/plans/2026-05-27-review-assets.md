# review-assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the growth-marketer `review-assets` skill as a self-contained consistency QA and publish-gate checklist.

**Architecture:** Mirror the existing `analyze-service` skill layout exactly: skill-owned `SKILL.md`, schema, copied validator, fixtures, bats tests, and baked references. The JSON companion artifact is the machine gate; the Markdown checklist is the human gate consumed before `draft-campaign`.

**Tech Stack:** Bash, jq, bats, JSON schema hint validation via `x-required`, `x-required-item`, and `x-required-when`.

---

## File Structure

- Create: `claude-plugins/growth-marketer/skills/review-assets/SKILL.md`
- Create: `claude-plugins/growth-marketer/skills/review-assets/schemas/review-checklist.schema.json`
- Create: `claude-plugins/growth-marketer/skills/review-assets/scripts/validate-artifact.sh`
- Create: `claude-plugins/growth-marketer/skills/review-assets/references/quality-standards.md`
- Create: `claude-plugins/growth-marketer/skills/review-assets/tests/validate-artifact.bats`
- Create: `claude-plugins/growth-marketer/skills/review-assets/tests/fixtures/review-checklist.valid.json`
- Create: `claude-plugins/growth-marketer/skills/review-assets/tests/fixtures/review-checklist.invalid.json`
- Create: `claude-plugins/growth-marketer/skills/review-assets/tests/fixtures/review-checklist.fail-noblocking.invalid.json`
- Create: `.agents/plugins/plugins/growth-marketer/skills/review-assets/**` by copying the Claude skill after green.

### Schema Decision

`review-checklist.schema.json` will require `service_slug`, `reviewed_at`, `reviewed_artifacts`, `findings`, and `gate_status` at top level. `findings[]` items require `artifact`, `dimension`, `severity`, and `recommendation`. `gate_status` accepts `pass` or `fail`. `x-required-when` requires `blocking_findings` when `gate_status` is `fail`, because `draft-campaign` needs a deterministic publish gate and a failed gate must expose the specific blockers.

## Task 1: Plan Commit

**Files:**
- Create: `docs/superpowers/plans/2026-05-27-review-assets.md`

- [ ] **Step 1: Save this plan**

Run: `test -f docs/superpowers/plans/2026-05-27-review-assets.md`

Expected: exit 0.

- [ ] **Step 2: Commit the plan before implementation**

Run:

```bash
git add docs/superpowers/plans/2026-05-27-review-assets.md
git commit -m "plan: add review-assets implementation plan"
```

Expected: commit succeeds on `feat/gm-review-assets`.

## Task 2: RED Tests for review-checklist Contract

**Files:**
- Create: `claude-plugins/growth-marketer/skills/review-assets/tests/validate-artifact.bats`
- Create: `claude-plugins/growth-marketer/skills/review-assets/tests/fixtures/review-checklist.valid.json`
- Create: `claude-plugins/growth-marketer/skills/review-assets/tests/fixtures/review-checklist.invalid.json`
- Create: `claude-plugins/growth-marketer/skills/review-assets/tests/fixtures/review-checklist.fail-noblocking.invalid.json`

- [ ] **Step 1: Write fixtures**

Create a passing fixture with `gate_status: "fail"` plus `blocking_findings`, one invalid fixture missing top-level and item fields, and one conditional invalid fixture where `gate_status` is `fail` but `blocking_findings` is missing.

- [ ] **Step 2: Write bats tests**

Tests must assert:

```bash
bats claude-plugins/growth-marketer/skills/review-assets/tests/validate-artifact.bats
```

Expected initial RED: fail because `scripts/validate-artifact.sh` and `schemas/review-checklist.schema.json` do not exist yet.

- [ ] **Step 3: Verify RED**

Run the bats command and confirm a non-zero exit caused by missing validator/schema, not by bats syntax.

## Task 3: GREEN Implementation for Claude Skill

**Files:**
- Create: `claude-plugins/growth-marketer/skills/review-assets/SKILL.md`
- Create: `claude-plugins/growth-marketer/skills/review-assets/schemas/review-checklist.schema.json`
- Create: `claude-plugins/growth-marketer/skills/review-assets/scripts/validate-artifact.sh`
- Create: `claude-plugins/growth-marketer/skills/review-assets/references/quality-standards.md`

- [ ] **Step 1: Copy validator verbatim**

Run:

```bash
mkdir -p claude-plugins/growth-marketer/skills/review-assets/{schemas,scripts,references,tests/fixtures}
cp claude-plugins/growth-marketer/skills/analyze-service/scripts/validate-artifact.sh \
  claude-plugins/growth-marketer/skills/review-assets/scripts/validate-artifact.sh
```

Expected: `cmp -s` against analyze-service validator succeeds.

- [ ] **Step 2: Add schema**

Create `review-checklist.schema.json` with `x-required`, item requirements, and fail-gate `x-required-when`.

- [ ] **Step 3: Add quality standards reference**

Summarize brand voice, message clarity, claim/evidence integrity, channel-fit, CRO readability, experiment discipline, and dark-pattern avoidance. Preserve source links from `docs/growth-marketer-research/cognitive-techniques.md` and `docs/growth-marketer-research/conversion-and-positioning.md`.

- [ ] **Step 4: Add SKILL.md**

Describe triggers for "일관성 검토", "자산 QA", "브랜드 보이스 점검", "발행 전 체크", and "리뷰 체크리스트". Procedure must gather all `.growth-marketer/<slug>/` artifacts, grade each against `quality-standards.md`, emit `review-checklist.md` and `review-checklist.json`, validate JSON, and state it is the `draft-campaign` publish gate.

- [ ] **Step 5: Verify GREEN**

Run:

```bash
bats claude-plugins/growth-marketer/skills/review-assets/tests/validate-artifact.bats
cmp -s claude-plugins/growth-marketer/skills/analyze-service/scripts/validate-artifact.sh \
  claude-plugins/growth-marketer/skills/review-assets/scripts/validate-artifact.sh
```

Expected: bats passes and cmp exits 0.

- [ ] **Step 6: Commit Claude skill**

Run:

```bash
git add claude-plugins/growth-marketer/skills/review-assets
git commit -m "feat(growth-marketer): add review-assets skill"
```

Expected: commit succeeds.

## Task 4: Codex Mirror

**Files:**
- Create: `.agents/plugins/plugins/growth-marketer/skills/review-assets/**`

- [ ] **Step 1: Copy Claude skill into Codex mirror**

Run:

```bash
rm -rf .agents/plugins/plugins/growth-marketer/skills/review-assets
cp -R claude-plugins/growth-marketer/skills/review-assets .agents/plugins/plugins/growth-marketer/skills/review-assets
```

Expected: mirror directory exists.

- [ ] **Step 2: Verify both copies**

Run:

```bash
bats claude-plugins/growth-marketer/skills/review-assets/tests/validate-artifact.bats
bats .agents/plugins/plugins/growth-marketer/skills/review-assets/tests/validate-artifact.bats
diff -qr claude-plugins/growth-marketer/skills/review-assets .agents/plugins/plugins/growth-marketer/skills/review-assets
```

Expected: both bats suites pass and `diff -qr` has no output.

- [ ] **Step 3: Commit mirror**

Run:

```bash
git add .agents/plugins/plugins/growth-marketer/skills/review-assets
git commit -m "chore(growth-marketer): mirror review-assets for codex"
```

Expected: commit succeeds.

## Task 5: Final Verification

**Files:**
- Verify only.

- [ ] **Step 1: Verify required file inventory**

Run:

```bash
test -f claude-plugins/growth-marketer/skills/review-assets/SKILL.md
test -f claude-plugins/growth-marketer/skills/review-assets/schemas/review-checklist.schema.json
test -f claude-plugins/growth-marketer/skills/review-assets/scripts/validate-artifact.sh
test -f claude-plugins/growth-marketer/skills/review-assets/references/quality-standards.md
test -f claude-plugins/growth-marketer/skills/review-assets/tests/validate-artifact.bats
test -f claude-plugins/growth-marketer/skills/review-assets/tests/fixtures/review-checklist.valid.json
test -f claude-plugins/growth-marketer/skills/review-assets/tests/fixtures/review-checklist.invalid.json
test -f claude-plugins/growth-marketer/skills/review-assets/tests/fixtures/review-checklist.fail-noblocking.invalid.json
```

Expected: all commands exit 0.

- [ ] **Step 2: Verify validator identity and tests**

Run:

```bash
cmp -s claude-plugins/growth-marketer/skills/analyze-service/scripts/validate-artifact.sh \
  claude-plugins/growth-marketer/skills/review-assets/scripts/validate-artifact.sh
bats claude-plugins/growth-marketer/skills/review-assets/tests/validate-artifact.bats
bats .agents/plugins/plugins/growth-marketer/skills/review-assets/tests/validate-artifact.bats
```

Expected: cmp exits 0 and both bats suites pass.

- [ ] **Step 3: Verify clean branch**

Run:

```bash
git status --short
git branch --show-current
git rev-list --count main..HEAD
```

Expected: status output is empty, branch is `feat/gm-review-assets`, commit count is a positive integer.


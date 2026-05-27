# Generate Copy Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the `generate-copy` growth-marketer skill as a self-contained, schema-validated skill that consumes `service-profile.json` and emits annotated copy artifacts.

**Architecture:** Mirror `analyze-service` exactly: one skill directory with `SKILL.md`, generic copied validator script, schemas, data contracts, baked references, fixtures, and Bats tests. The implementation is documentation/data/schema only; no API keys, model calls, network, browser, plugin manifest edits, or shared plugin-level directories.

**Tech Stack:** Bash, `jq`, Bats, Markdown, JSON schemas using the existing `x-required`, `x-required-item`, and nested `x-required` validation hints.

---

### Task 1: Commit The Plan

**Files:**
- Create: `docs/superpowers/plans/2026-05-27-generate-copy.md`

**Step 1: Verify plan file exists**

Run: `test -f docs/superpowers/plans/2026-05-27-generate-copy.md`

Expected: exit 0.

**Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-05-27-generate-copy.md
git commit -m "docs: plan generate-copy skill"
```

### Task 2: Write Failing Contract Tests

**Files:**
- Create: `claude-plugins/growth-marketer/skills/generate-copy/tests/validate-artifact.bats`
- Create fixtures under: `claude-plugins/growth-marketer/skills/generate-copy/tests/fixtures/`

**Step 1: Write Bats tests first**

Add tests mirroring `analyze-service/tests/validate-artifact.bats`:
- `copy valid fixture passes`
- `copy invalid fixture fails with missing-field message`
- `copy invalid technique fixture names missing source_ref`
- `copy-templates valid fixture passes`
- `copy-templates invalid fixture fails and names required field`
- `technique-index valid fixture passes`
- `technique-index invalid fixture fails and names required field`
- shared validator behavior for missing artifact, non-JSON artifact, and unknown schema.

Fixtures:
- `copy.valid.json`
- `copy.invalid.json` missing top-level `channel` and at least one variant `text`
- `copy.technique-source-ref.invalid.json` missing `source_ref` inside a nested technique reference
- `copy-templates.valid.json`
- `copy-templates.invalid.json` missing template `format`
- `technique-index.valid.json`
- `technique-index.invalid.json` missing technique `source_ref`

**Step 2: Run RED**

Run: `bats claude-plugins/growth-marketer/skills/generate-copy/tests/validate-artifact.bats`

Expected: FAIL because `scripts/validate-artifact.sh` and schemas do not exist yet.

**Step 3: Commit RED tests**

```bash
git add claude-plugins/growth-marketer/skills/generate-copy/tests
git commit -m "test: add generate-copy contract tests"
```

### Task 3: Add Schemas And Validator

**Files:**
- Copy verbatim: `claude-plugins/growth-marketer/skills/generate-copy/scripts/validate-artifact.sh`
- Create: `claude-plugins/growth-marketer/skills/generate-copy/schemas/copy.schema.json`
- Create: `claude-plugins/growth-marketer/skills/generate-copy/schemas/copy-templates.schema.json`
- Create: `claude-plugins/growth-marketer/skills/generate-copy/schemas/technique-index.schema.json`

**Step 1: Copy validator verbatim**

Run:
```bash
mkdir -p claude-plugins/growth-marketer/skills/generate-copy/scripts
cp claude-plugins/growth-marketer/skills/analyze-service/scripts/validate-artifact.sh \
  claude-plugins/growth-marketer/skills/generate-copy/scripts/validate-artifact.sh
```

Expected: `diff -u` between the two validator scripts is empty.

**Step 2: Add minimal schemas**

Schema shapes:
- `copy.schema.json`: top-level `service_slug`, `generated_at`, `asset_type`, `channel`, `source_profile`, `variants`, `measurement`; each variant requires `id`, `label`, `text`, `techniques`; each technique object requires `id`, `source_ref`.
- `copy-templates.schema.json`: top-level `version`, `templates`; each template requires `asset_type`, `channel`, `format`, `constraints`, `variant_count`.
- `technique-index.schema.json`: top-level `version`, `techniques`; each technique requires `id`, `name`, `source_ref`, `applicable_channels`, `applicable_asset_types`, `bounds`.

**Step 3: Run GREEN for contract tests**

Run: `bats claude-plugins/growth-marketer/skills/generate-copy/tests/validate-artifact.bats`

Expected: all tests pass.

**Step 4: Commit**

```bash
git add claude-plugins/growth-marketer/skills/generate-copy/scripts \
  claude-plugins/growth-marketer/skills/generate-copy/schemas
git commit -m "feat: add generate-copy artifact schemas"
```

### Task 4: Add Data Files And Baked References

**Files:**
- Create: `claude-plugins/growth-marketer/skills/generate-copy/data/copy-templates.json`
- Create: `claude-plugins/growth-marketer/skills/generate-copy/data/technique-index.json`
- Create: `claude-plugins/growth-marketer/skills/generate-copy/references/cognitive-psychology/technique-catalog.md`
- Create: `claude-plugins/growth-marketer/skills/generate-copy/references/frameworks/offer-positioning-email.md`

**Step 1: Add skill-owned data files**

Populate `copy-templates.json` for ad/CTA, landing-page, email-sequence, and organic-social across relevant channels. Populate `technique-index.json` with technique IDs from the baked cognitive catalog and explicit applicability by channel and asset type.

**Step 2: Add baked references**

Summarize only the relevant source slices:
- cognitive psychology techniques with source links and explicit out-of-bounds notes for deceptive scarcity, false urgency, fake proof, fabricated anchors, and manipulative fear.
- offer, positioning, hook model, value proposition, and lifecycle email sections from `conversion-and-positioning.md`; exclude CRO audit-specific material.

**Step 3: Validate data files**

Run:
```bash
bash claude-plugins/growth-marketer/skills/generate-copy/scripts/validate-artifact.sh copy-templates claude-plugins/growth-marketer/skills/generate-copy/data/copy-templates.json
bash claude-plugins/growth-marketer/skills/generate-copy/scripts/validate-artifact.sh technique-index claude-plugins/growth-marketer/skills/generate-copy/data/technique-index.json
bats claude-plugins/growth-marketer/skills/generate-copy/tests/validate-artifact.bats
```

Expected: all commands pass.

**Step 4: Commit**

```bash
git add claude-plugins/growth-marketer/skills/generate-copy/data \
  claude-plugins/growth-marketer/skills/generate-copy/references
git commit -m "feat: add generate-copy data and references"
```

### Task 5: Add SKILL.md

**Files:**
- Create: `claude-plugins/growth-marketer/skills/generate-copy/SKILL.md`

**Step 1: Author skill instructions**

Include front matter:
- `name: generate-copy`
- description triggers: `카피 써줘`, `광고 문구 만들어`, `랜딩 카피`, `이메일 시퀀스`, `인지심리 기반 카피`

Procedure:
1. Read `.growth-marketer/<slug>/service-profile.json` produced by `analyze-service`.
2. Choose target channel, asset type, and techniques.
3. Use `data/copy-templates.json`, `data/technique-index.json`, and baked references.
4. Emit `.growth-marketer/<slug>/copy/<asset>-<channel>.md` with annotated variants, technique IDs, source refs, hypothesis, metric, and guardrail metric.
5. Maintain safety guardrails: no deceptive scarcity, false urgency, fabricated proof, fake countdowns, fake testimonials, or manipulative fear.
6. Validate any machine-readable companion artifact using `scripts/validate-artifact.sh copy`.

**Step 2: Run tests**

Run: `bats claude-plugins/growth-marketer/skills/generate-copy/tests/validate-artifact.bats`

Expected: pass.

**Step 3: Commit**

```bash
git add claude-plugins/growth-marketer/skills/generate-copy/SKILL.md
git commit -m "feat: add generate-copy skill guide"
```

### Task 6: Mirror To Codex Plugin Tree

**Files:**
- Create mirror: `.agents/plugins/plugins/growth-marketer/skills/generate-copy/`

**Step 1: Copy mirror**

Run:
```bash
rm -rf .agents/plugins/plugins/growth-marketer/skills/generate-copy
cp -R claude-plugins/growth-marketer/skills/generate-copy .agents/plugins/plugins/growth-marketer/skills/generate-copy
```

**Step 2: Verify source and mirror**

Run:
```bash
bats claude-plugins/growth-marketer/skills/generate-copy/tests/validate-artifact.bats
bats .agents/plugins/plugins/growth-marketer/skills/generate-copy/tests/validate-artifact.bats
diff -r claude-plugins/growth-marketer/skills/generate-copy .agents/plugins/plugins/growth-marketer/skills/generate-copy
```

Expected: both Bats suites pass and `diff -r` exits 0.

**Step 3: Commit**

```bash
git add .agents/plugins/plugins/growth-marketer/skills/generate-copy
git commit -m "chore: mirror generate-copy skill for codex"
```

### Task 7: Final Verification

**Files:**
- Read-only verification.

**Step 1: Run final checks**

Run:
```bash
bats claude-plugins/growth-marketer/skills/generate-copy/tests/validate-artifact.bats
bats .agents/plugins/plugins/growth-marketer/skills/generate-copy/tests/validate-artifact.bats
diff -r claude-plugins/growth-marketer/skills/generate-copy .agents/plugins/plugins/growth-marketer/skills/generate-copy
git status --short --branch
git log --oneline --decorate --max-count=10
```

Expected: both suites pass, diff exits 0, branch is `feat/gm-generate-copy`, and there are no uncommitted files.

**Step 2: Done signal**

Print exactly:

```text
GM_WORKER_DONE generate-copy commits=<N> bats=pass
```

# Channel Playbook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the `channel-playbook` growth-marketer skill, with baked channel references and a validated playbook companion contract.

**Architecture:** The skill is self-contained under `skills/channel-playbook/`, mirroring `analyze-service`: a concise `SKILL.md`, local `references/channels/`, local `schemas/`, local `scripts/`, and local bats fixtures. The playbook Markdown is the human artifact, while `playbook.json` is the structured companion validated by the copied generic `validate-artifact.sh`.

**Tech Stack:** Markdown, JSON schema hint fields (`x-required`, nested `x-required`, `x-required-item`), bash, jq, bats.

---

## File Structure

- Create `claude-plugins/growth-marketer/skills/channel-playbook/SKILL.md` — downstream procedure that consumes `analyze-service` `service-profile.json`.
- Create `claude-plugins/growth-marketer/skills/channel-playbook/schemas/playbook.schema.json` — companion contract for playbook content.
- Copy `claude-plugins/growth-marketer/skills/analyze-service/scripts/validate-artifact.sh` verbatim to `claude-plugins/growth-marketer/skills/channel-playbook/scripts/validate-artifact.sh`.
- Create `claude-plugins/growth-marketer/skills/channel-playbook/tests/validate-artifact.bats` — contract tests matching the exemplar style.
- Create `claude-plugins/growth-marketer/skills/channel-playbook/tests/fixtures/playbook.valid.json` and `playbook.invalid.json`.
- Create six baked channel references in `claude-plugins/growth-marketer/skills/channel-playbook/references/channels/`:
  - `meta-ads.md`
  - `google-ads-uac.md`
  - `naver-search-gfa.md`
  - `aso.md`
  - `seo-content.md`
  - `retargeting.md`
- Mirror the completed skill to `.agents/plugins/plugins/growth-marketer/skills/channel-playbook/` after the Claude copy is green.

The `playbook.schema.json` contract uses these required fields: `channel`, `generated_at`, `service_slug`, `targeting`, `budget_guidance`, `creative_specs`, `kpis`, and `tailored_from`. `targeting`, `budget_guidance`, `creative_specs`, and `kpis` are objects with nested required fields so missing sections report useful field names. `tailored_from[]` requires `source` and `claim` per item to preserve source tracking from the baked research.

---

### Task 1: Plan Commit

**Files:**
- Create: `docs/superpowers/plans/2026-05-27-channel-playbook.md`

- [ ] **Step 1: Save this plan**

Run: `test -f docs/superpowers/plans/2026-05-27-channel-playbook.md`
Expected: exit 0.

- [ ] **Step 2: Commit the plan before implementation**

```bash
git add docs/superpowers/plans/2026-05-27-channel-playbook.md
git commit -m "plan(growth-marketer): channel-playbook TDD plan"
```

---

### Task 2: Playbook Contract RED/GREEN

**Files:**
- Create: `claude-plugins/growth-marketer/skills/channel-playbook/tests/validate-artifact.bats`
- Create: `claude-plugins/growth-marketer/skills/channel-playbook/tests/fixtures/playbook.valid.json`
- Create: `claude-plugins/growth-marketer/skills/channel-playbook/tests/fixtures/playbook.invalid.json`
- Create: `claude-plugins/growth-marketer/skills/channel-playbook/schemas/playbook.schema.json`
- Create: `claude-plugins/growth-marketer/skills/channel-playbook/scripts/validate-artifact.sh`

- [ ] **Step 1: Write the failing bats tests and fixtures**

Create `tests/validate-artifact.bats`:

```bash
#!/usr/bin/env bats

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VALIDATE="$ROOT/scripts/validate-artifact.sh"
FIX="$ROOT/tests/fixtures"

@test "playbook valid fixture passes" {
  run "$VALIDATE" playbook "$FIX/playbook.valid.json"
  [ "$status" -eq 0 ]
}

@test "playbook invalid fixture fails with missing-field message" {
  run "$VALIDATE" playbook "$FIX/playbook.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"budget_guidance"* ]]
  [[ "$output" == *"creative_specs.aspect_ratios"* ]]
  [[ "$output" == *"array 'tailored_from'"* ]]
  [[ "$output" == *"claim"* ]]
}

@test "missing artifact file exits 2" {
  run "$VALIDATE" playbook "$FIX/does-not-exist.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "non-JSON artifact exits 2" {
  tmp="$(mktemp)"; printf 'not json' > "$tmp"
  run "$VALIDATE" playbook "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 2 ]
}

@test "unknown schema name exits 2" {
  run "$VALIDATE" no-such-schema "$FIX/playbook.valid.json"
  [ "$status" -eq 2 ]
}
```

Create `tests/fixtures/playbook.valid.json`:

```json
{
  "channel": "meta-ads",
  "generated_at": "2026-05-27T09:00:00Z",
  "service_slug": "focus-tracker",
  "targeting": {
    "primary_audience": "B2C mobile users who want daily focus routines",
    "segments": ["habit builders", "productivity app switchers"],
    "exclusions": ["existing paid subscribers"]
  },
  "budget_guidance": {
    "starting_budget": "Use a small daily learning budget until conversion events stabilize.",
    "bidding": "Optimize for trial_start or purchase once events are available.",
    "guardrails": ["Do not optimize for traffic when paid conversion is the goal."]
  },
  "creative_specs": {
    "formats": ["short vertical video", "square product screenshot"],
    "aspect_ratios": ["9:16", "1:1"],
    "message_angles": ["finish today with less context switching", "build a focus streak in minutes"]
  },
  "kpis": {
    "primary": ["cost per trial_start", "trial-to-paid conversion rate"],
    "secondary": ["thumbstop rate", "landing conversion rate"],
    "measurement_notes": "Compare ad promise to first-screen landing message."
  },
  "tailored_from": [
    {
      "source": "references/channels/meta-ads.md#sources-s1-s7",
      "claim": "Meta objective choice should match the conversion event used for delivery optimization."
    }
  ]
}
```

Create `tests/fixtures/playbook.invalid.json`:

```json
{
  "channel": "meta-ads",
  "generated_at": "2026-05-27T09:00:00Z",
  "service_slug": "focus-tracker",
  "targeting": {
    "primary_audience": "B2C mobile users",
    "segments": ["habit builders"]
  },
  "creative_specs": {
    "formats": ["short vertical video"]
  },
  "kpis": {
    "primary": ["cost per trial_start"],
    "measurement_notes": "Track downstream quality."
  },
  "tailored_from": [
    {
      "source": "references/channels/meta-ads.md#sources-s1-s7"
    }
  ]
}
```

- [ ] **Step 2: Copy the generic validator verbatim**

Run:

```bash
mkdir -p claude-plugins/growth-marketer/skills/channel-playbook/scripts
cp claude-plugins/growth-marketer/skills/analyze-service/scripts/validate-artifact.sh \
  claude-plugins/growth-marketer/skills/channel-playbook/scripts/validate-artifact.sh
```

- [ ] **Step 3: Run RED**

Run: `bats claude-plugins/growth-marketer/skills/channel-playbook/tests/validate-artifact.bats`
Expected: FAIL because `schemas/playbook.schema.json` does not exist; the valid test exits 2 instead of 0.

- [ ] **Step 4: Create the playbook schema**

Create `schemas/playbook.schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "playbook",
  "description": "Structured companion contract for channel-playbook Markdown artifacts.",
  "type": "object",
  "x-required": ["channel", "generated_at", "service_slug", "targeting", "budget_guidance", "creative_specs", "kpis", "tailored_from"],
  "properties": {
    "channel": { "type": "string", "enum": ["meta-ads", "google-ads-uac", "naver-search-gfa", "aso", "seo-content", "retargeting"] },
    "generated_at": { "type": "string", "description": "UTC ISO8601 timestamp." },
    "service_slug": { "type": "string" },
    "targeting": {
      "type": "object",
      "x-required": ["primary_audience", "segments"],
      "properties": {
        "primary_audience": { "type": "string" },
        "segments": { "type": "array", "items": { "type": "string" } },
        "exclusions": { "type": "array", "items": { "type": "string" } }
      }
    },
    "budget_guidance": {
      "type": "object",
      "x-required": ["starting_budget", "bidding", "guardrails"],
      "properties": {
        "starting_budget": { "type": "string" },
        "bidding": { "type": "string" },
        "guardrails": { "type": "array", "items": { "type": "string" } }
      }
    },
    "creative_specs": {
      "type": "object",
      "x-required": ["formats", "aspect_ratios", "message_angles"],
      "properties": {
        "formats": { "type": "array", "items": { "type": "string" } },
        "aspect_ratios": { "type": "array", "items": { "type": "string" } },
        "message_angles": { "type": "array", "items": { "type": "string" } }
      }
    },
    "kpis": {
      "type": "object",
      "x-required": ["primary", "measurement_notes"],
      "properties": {
        "primary": { "type": "array", "items": { "type": "string" } },
        "secondary": { "type": "array", "items": { "type": "string" } },
        "measurement_notes": { "type": "string" }
      }
    },
    "tailored_from": {
      "type": "array",
      "items": {
        "type": "object",
        "x-required-item": ["source", "claim"],
        "properties": {
          "source": { "type": "string" },
          "claim": { "type": "string" }
        }
      }
    }
  }
}
```

- [ ] **Step 5: Run GREEN**

Run: `bats claude-plugins/growth-marketer/skills/channel-playbook/tests/validate-artifact.bats`
Expected: 5/5 pass.

- [ ] **Step 6: Commit**

```bash
git add claude-plugins/growth-marketer/skills/channel-playbook
git commit -m "feat(growth-marketer): add channel-playbook contract tests"
```

---

### Task 3: Skill Instructions and Baked Channel References

**Files:**
- Create: `claude-plugins/growth-marketer/skills/channel-playbook/SKILL.md`
- Create: six files under `claude-plugins/growth-marketer/skills/channel-playbook/references/channels/`

- [ ] **Step 1: Write concise baked references**

Each reference must include: when to choose the channel, targeting, budget/bidding, creative specs, KPI measurement, and source links copied from `docs/growth-marketer-research/channels.md`.

- [ ] **Step 2: Write `SKILL.md`**

The front matter must include `name: channel-playbook` and a description with the trigger phrases "채널 플레이북", "메타 광고 어떻게 세팅", "네이버 광고 플레이북", and "이 채널 운영 가이드". The procedure must say to read `.growth-marketer/<slug>/service-profile.json`, select a channel, read the matching baked reference, emit `.growth-marketer/<slug>/playbook-<channel>.md` plus a structured companion JSON, validate with `scripts/validate-artifact.sh`, and report the saved paths.

- [ ] **Step 3: Run the existing contract tests**

Run: `bats claude-plugins/growth-marketer/skills/channel-playbook/tests/validate-artifact.bats`
Expected: 5/5 pass.

- [ ] **Step 4: Commit**

```bash
git add claude-plugins/growth-marketer/skills/channel-playbook/SKILL.md \
        claude-plugins/growth-marketer/skills/channel-playbook/references/channels
git commit -m "feat(growth-marketer): add channel-playbook skill references"
```

---

### Task 4: Codex Mirror and Final Verification

**Files:**
- Create: `.agents/plugins/plugins/growth-marketer/skills/channel-playbook/`

- [ ] **Step 1: Mirror the completed skill**

Run:

```bash
rm -rf .agents/plugins/plugins/growth-marketer/skills/channel-playbook
cp -R claude-plugins/growth-marketer/skills/channel-playbook \
  .agents/plugins/plugins/growth-marketer/skills/channel-playbook
```

- [ ] **Step 2: Verify Claude copy**

Run: `bats claude-plugins/growth-marketer/skills/channel-playbook/tests/validate-artifact.bats`
Expected: 5/5 pass.

- [ ] **Step 3: Verify Codex mirror copy**

Run: `bats .agents/plugins/plugins/growth-marketer/skills/channel-playbook/tests/validate-artifact.bats`
Expected: 5/5 pass.

- [ ] **Step 4: Verify copied validator stayed identical**

Run:

```bash
cmp -s claude-plugins/growth-marketer/skills/analyze-service/scripts/validate-artifact.sh \
  claude-plugins/growth-marketer/skills/channel-playbook/scripts/validate-artifact.sh
```

Expected: exit 0.

- [ ] **Step 5: Commit the mirror**

```bash
git add .agents/plugins/plugins/growth-marketer/skills/channel-playbook
git commit -m "chore(growth-marketer): mirror channel-playbook for codex"
```

- [ ] **Step 6: Final status**

Run: `git status --short --branch`
Expected: branch `feat/gm-channel-playbook` with a clean worktree. Do not push or merge.

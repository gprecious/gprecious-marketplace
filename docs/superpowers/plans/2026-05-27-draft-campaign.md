# TDD Plan: growth-marketer draft-campaign

## Scope

Build only `claude-plugins/growth-marketer/skills/draft-campaign/`, then mirror it to
`.agents/plugins/plugins/growth-marketer/skills/draft-campaign/`.

Do not edit `plugin.json`, marketplace files, or unrelated growth-marketer skills.

## Contract Decisions

- `draft_status` enum: `planned`, `entered`, `blocked`.
- `published` is intentionally absent from the enum and must never appear as a valid state.
- `review_checklist_ref` is a structured object with `path` and `gate_status`.
- `draft_status="entered"` requires `review_checklist_ref`, `screenshots`, `draft_diff`,
  and `confirmation_checklist`.
- `review_checklist_ref` is also top-level required so every draft records the review-assets
  gate state. If `gate_status` is not `pass`, the procedure must leave the draft blocked.
- The generic validator only enforces presence and conditional presence via `x-*` hints, so
  tests cover publish-forbidden invariants through fixtures and visible failure messages.

## Tasks

1. RED: create `draft-campaign` tests and fixtures before implementation.
   - Add `tests/validate-artifact.bats`.
   - Add fixtures:
     - `campaign-draft.valid.json`
     - `campaign-draft.invalid.json`
     - `campaign-draft.entered-nogate.invalid.json`
     - `campaign-draft.published.invalid.json`
   - Run bats and confirm it fails because the validator/schema do not exist yet.

2. GREEN: add the self-contained skill implementation.
   - Copy `scripts/validate-artifact.sh` byte-identically from `analyze-service`.
   - Add `schemas/campaign-draft.schema.json`.
   - Add `SKILL.md` with triggers, procedure, output contract, and a loud
     publish-forbidden safety section.
   - Run bats for the Claude skill until green.

3. Verify byte identity and safety text.
   - Compare `validate-artifact.sh` against `analyze-service` with `cmp -s`.
   - Grep `SKILL.md` for explicit publish-forbidden language.
   - Confirm the schema does not allow `published`.

4. Mirror to the Codex plugin tree.
   - Remove any existing Codex mirror for `draft-campaign`.
   - Copy the Claude skill directory into `.agents/plugins/plugins/growth-marketer/skills/`.
   - Run the same bats suite in both copies.

5. Final checks.
   - Verify required files exist in both trees.
   - Verify `git status --short` is clean after commits.
   - Report `GM_WORKER_DONE draft-campaign commits=<integer> bats=pass`.

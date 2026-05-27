#!/usr/bin/env bats

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VALIDATE="$ROOT/scripts/validate-artifact.sh"
FIX="$ROOT/tests/fixtures"
SCHEMA="$ROOT/schemas/campaign-draft.schema.json"

@test "campaign-draft valid fixture passes" {
  run "$VALIDATE" campaign-draft "$FIX/campaign-draft.valid.json"
  [ "$status" -eq 0 ]
}

@test "campaign-draft invalid fixture fails with missing-field messages" {
  run "$VALIDATE" campaign-draft "$FIX/campaign-draft.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"channel"* ]]
  [[ "$output" == *"field_map"* ]]
  [[ "$output" == *"review_checklist_ref"* ]]
  [[ "$output" == *"screenshots"* ]]
}

@test "entered draft without pass gate and screenshots fails conditional gate" {
  run "$VALIDATE" campaign-draft "$FIX/campaign-draft.entered-nogate.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"review_checklist_ref"* ]]
  [[ "$output" == *"screenshots"* ]]
  [[ "$output" == *"draft_diff"* ]]
  [[ "$output" == *"confirmation_checklist"* ]]
}

@test "published status is rejected as publish-forbidden violation" {
  run "$VALIDATE" campaign-draft "$FIX/campaign-draft.published.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PUBLISH_FORBIDDEN"* ]]
}

@test "entered draft requires review-assets gate_status pass" {
  run bash -c "\"$VALIDATE\" campaign-draft \"$FIX/campaign-draft.entered-gate-fail.invalid.json\" && jq -e '.draft_status != \"entered\" or .review_checklist_ref.gate_status == \"pass\"' \"$FIX/campaign-draft.entered-gate-fail.invalid.json\""
  [ "$status" -eq 1 ]
}

@test "schema does not allow published draft_status" {
  run jq -e '.properties.draft_status.enum | index("published") | not' "$SCHEMA"
  [ "$status" -eq 0 ]
}

@test "missing artifact file exits 2" {
  run "$VALIDATE" campaign-draft "$FIX/does-not-exist.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "non-JSON artifact exits 2" {
  tmp="$(mktemp)"
  printf 'not json' > "$tmp"
  run "$VALIDATE" campaign-draft "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 2 ]
}

@test "unknown schema name exits 2" {
  run "$VALIDATE" no-such-schema "$FIX/campaign-draft.valid.json"
  [ "$status" -eq 2 ]
}

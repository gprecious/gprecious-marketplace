#!/usr/bin/env bats

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VALIDATE="$ROOT/scripts/validate-artifact.sh"
FIX="$ROOT/tests/fixtures"

@test "review-checklist valid fixture passes" {
  run "$VALIDATE" review-checklist "$FIX/review-checklist.valid.json"
  [ "$status" -eq 0 ]
}

@test "review-checklist invalid fixture fails with missing-field messages" {
  run "$VALIDATE" review-checklist "$FIX/review-checklist.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gate_status"* ]]
  [[ "$output" == *"array 'reviewed_artifacts'"* ]]
  [[ "$output" == *"source_path"* ]]
  [[ "$output" == *"array 'findings'"* ]]
  [[ "$output" == *"recommendation"* ]]
}

@test "review-checklist fail gate requires blocking findings" {
  run "$VALIDATE" review-checklist "$FIX/review-checklist.fail-noblocking.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"blocking_findings"* ]]
  [[ "$output" == *"gate_status"* ]]
  [[ "$output" == *"fail"* ]]
}

@test "missing artifact file exits 2" {
  run "$VALIDATE" review-checklist "$FIX/does-not-exist.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "non-JSON artifact exits 2" {
  tmp="$(mktemp)"; printf 'not json' > "$tmp"
  run "$VALIDATE" review-checklist "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 2 ]
}

@test "unknown schema name exits 2" {
  run "$VALIDATE" no-such-schema "$FIX/review-checklist.valid.json"
  [ "$status" -eq 2 ]
}

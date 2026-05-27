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

#!/usr/bin/env bats

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VALIDATE="$ROOT/scripts/validate-artifact.sh"
FIX="$ROOT/tests/fixtures"

@test "service-profile valid fixture passes" {
  run "$VALIDATE" service-profile "$FIX/service-profile.valid.json"
  [ "$status" -eq 0 ]
}

@test "service-profile invalid fixture fails with missing-field message" {
  run "$VALIDATE" service-profile "$FIX/service-profile.invalid.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"positioning"* ]]
}

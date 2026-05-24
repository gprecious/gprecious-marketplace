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
  [ "$status" -eq 1 ]
  [[ "$output" == *"positioning"* ]]
  [[ "$output" == *"source_url"* ]]
}

@test "non-JSON artifact exits 2" {
  tmp="$(mktemp)"; printf 'not json' > "$tmp"
  run "$VALIDATE" service-profile "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 2 ]
}

@test "unknown schema name exits 2" {
  run "$VALIDATE" no-such-schema "$FIX/service-profile.valid.json"
  [ "$status" -eq 2 ]
}

@test "channel-scores valid fixture passes" {
  run "$VALIDATE" channel-scores "$FIX/channel-scores.valid.json"
  [ "$status" -eq 0 ]
}

@test "channel-scores invalid fixture fails" {
  run "$VALIDATE" channel-scores "$FIX/channel-scores.invalid.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"recommendation"* ]]
}

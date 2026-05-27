#!/usr/bin/env bats

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VALIDATE="$ROOT/scripts/validate-artifact.sh"
FIX="$ROOT/tests/fixtures"

@test "cro-audit valid fixture passes" {
  run "$VALIDATE" cro-audit "$FIX/cro-audit.valid.json"
  [ "$status" -eq 0 ]
}

@test "cro-audit invalid fixture fails with missing-field messages" {
  run "$VALIDATE" cro-audit "$FIX/cro-audit.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"captured_at"* ]]
  [[ "$output" == *"recommendation"* ]]
}

@test "missing artifact file exits 2" {
  run "$VALIDATE" cro-audit "$FIX/does-not-exist.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "non-JSON artifact exits 2" {
  tmp="$(mktemp)"; printf 'not json' > "$tmp"
  run "$VALIDATE" cro-audit "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 2 ]
}

@test "unknown schema name exits 2" {
  run "$VALIDATE" no-such-schema "$FIX/cro-audit.valid.json"
  [ "$status" -eq 2 ]
}

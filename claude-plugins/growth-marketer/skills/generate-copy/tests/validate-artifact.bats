#!/usr/bin/env bats

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VALIDATE="$ROOT/scripts/validate-artifact.sh"
FIX="$ROOT/tests/fixtures"

@test "copy valid fixture passes" {
  run "$VALIDATE" copy "$FIX/copy.valid.json"
  [ "$status" -eq 0 ]
}

@test "copy invalid fixture fails with missing-field message" {
  run "$VALIDATE" copy "$FIX/copy.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"channel"* ]]
  [[ "$output" == *"text"* ]]
}

@test "copy invalid technique fixture names missing source_ref" {
  run "$VALIDATE" copy "$FIX/copy.technique-source-ref.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"source_ref"* ]]
}

@test "missing artifact file exits 2" {
  run "$VALIDATE" copy "$FIX/does-not-exist.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "non-JSON artifact exits 2" {
  tmp="$(mktemp)"; printf 'not json' > "$tmp"
  run "$VALIDATE" copy "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 2 ]
}

@test "unknown schema name exits 2" {
  run "$VALIDATE" no-such-schema "$FIX/copy.valid.json"
  [ "$status" -eq 2 ]
}

@test "copy-templates valid fixture passes" {
  run "$VALIDATE" copy-templates "$FIX/copy-templates.valid.json"
  [ "$status" -eq 0 ]
}

@test "copy-templates invalid fixture fails and names required field" {
  run "$VALIDATE" copy-templates "$FIX/copy-templates.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"format"* ]]
}

@test "technique-index valid fixture passes" {
  run "$VALIDATE" technique-index "$FIX/technique-index.valid.json"
  [ "$status" -eq 0 ]
}

@test "technique-index invalid fixture fails and names required field" {
  run "$VALIDATE" technique-index "$FIX/technique-index.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"source_ref"* ]]
}

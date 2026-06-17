#!/usr/bin/env bats

SCAF="${BATS_TEST_DIRNAME}/../skills/e2e-harness/lib/scaffold.sh"

@test "nextjs-supabase render matches fuelai seed.ts byte-for-byte" {
  TMP="$(mktemp -d)"
  bash "$SCAF" --recipe nextjs-supabase --target "$TMP" --var port=3100 --var locales=ko,en
  # seed.ts has no vars → must equal the fuelai source exactly
  run diff "$TMP/e2e/seed.ts" /Users/qplacebot/projects/fuelai/apps/web/e2e/seed.ts
  [ "$status" -eq 0 ]
}

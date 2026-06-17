#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../skills/e2e-harness/lib/scaffold.sh"

setup() { TARGET="$(mktemp -d)"; }
teardown() { rm -rf "$TARGET"; }

@test "scaffold writes playwright config and is idempotent" {
  run bash "$SCRIPT" --recipe nextjs-supabase --target "$TARGET" --var port=3100 --var locales=ko,en
  [ "$status" -eq 0 ]
  [ -f "$TARGET/playwright.config.ts" ]
  [ -f "$TARGET/e2e/global-setup.ts" ]
  h1="$(shasum "$TARGET/playwright.config.ts" | cut -d' ' -f1)"
  run bash "$SCRIPT" --recipe nextjs-supabase --target "$TARGET" --var port=3100 --var locales=ko,en
  [ "$status" -eq 0 ]
  h2="$(shasum "$TARGET/playwright.config.ts" | cut -d' ' -f1)"
  [ "$h1" = "$h2" ]
}

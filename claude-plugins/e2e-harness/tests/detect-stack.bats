#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../skills/e2e-harness/lib/detect-stack.sh"

@test "detects nextjs + supabase" {
  run bash "$SCRIPT" "${BATS_TEST_DIRNAME}/fixtures/nextjs-supabase"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.framework=="nextjs" and .dbLayer=="supabase"'
}

@test "detects generic vite web" {
  run bash "$SCRIPT" "${BATS_TEST_DIRNAME}/fixtures/vite-web"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.framework=="vite" and .recipe=="generic-web-playwright"'
}

@test "non-web falls back" {
  run bash "$SCRIPT" "${BATS_TEST_DIRNAME}/fixtures/node-cli"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.recipe=="_fallback"'
}

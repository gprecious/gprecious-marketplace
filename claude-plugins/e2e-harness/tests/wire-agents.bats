#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../skills/e2e-harness/lib/wire-agents.sh"

setup() { TARGET="$(mktemp -d)"; }
teardown() { rm -rf "$TARGET"; }

@test "creates AGENTS.md with managed block when none exists" {
  run bash "$SCRIPT" --target "$TARGET" --run "pnpm test:e2e" --burnin "pnpm test:e2e:burnin"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/AGENTS.md" ]
  grep -qF "<!-- e2e-harness:start -->" "$TARGET/AGENTS.md"
  grep -qF "pnpm test:e2e" "$TARGET/AGENTS.md"
}

@test "is idempotent — re-run does not duplicate the block" {
  bash "$SCRIPT" --target "$TARGET" --run "pnpm test:e2e"
  bash "$SCRIPT" --target "$TARGET" --run "pnpm test:e2e"
  count="$(grep -cF "<!-- e2e-harness:start -->" "$TARGET/AGENTS.md")"
  [ "$count" -eq 1 ]
}

@test "merges into existing AGENTS.md, preserving prior content" {
  printf '# Existing\n\n기존 지침 보존되어야 함.\n' > "$TARGET/AGENTS.md"
  run bash "$SCRIPT" --target "$TARGET" --run "go test ./..."
  [ "$status" -eq 0 ]
  grep -qF "기존 지침 보존되어야 함." "$TARGET/AGENTS.md"
  grep -qF "go test ./..." "$TARGET/AGENTS.md"
  # 블록은 정확히 1개
  [ "$(grep -cF "<!-- e2e-harness:start -->" "$TARGET/AGENTS.md")" -eq 1 ]
}

@test "re-run updates the block content in place (run command changes)" {
  bash "$SCRIPT" --target "$TARGET" --run "pnpm test:e2e"
  bash "$SCRIPT" --target "$TARGET" --run "npm run e2e"
  grep -qF "npm run e2e" "$TARGET/AGENTS.md"
  ! grep -qF "pnpm test:e2e" "$TARGET/AGENTS.md"
  [ "$(grep -cF "<!-- e2e-harness:start -->" "$TARGET/AGENTS.md")" -eq 1 ]
}

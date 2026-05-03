#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../scripts/pane-status.sh"
  FIXTURES="$BATS_TEST_DIRNAME/../fixtures"
}

# ── detect_footer_type ──────────────────────────────────────────────────────────

@test "detect_footer_type recognizes claude footer" {
  run detect_footer_type "$(cat "$FIXTURES/capture_claude_idle.txt")"
  [ "$status" -eq 0 ]
  [ "$output" = "claude" ]
}

@test "detect_footer_type recognizes codex footer" {
  run detect_footer_type "$(cat "$FIXTURES/capture_codex_idle.txt")"
  [ "$status" -eq 0 ]
  [ "$output" = "codex" ]
}

@test "detect_footer_type returns none for plain shell capture" {
  run detect_footer_type "$(cat "$FIXTURES/capture_dead.txt")"
  [ "$status" -eq 0 ]
  [ "$output" = "none" ]
}

# ── detect_failure_signal ───────────────────────────────────────────────────────

@test "detect_failure_signal returns rate_limit with wait_seconds=45" {
  run detect_failure_signal "$(cat "$FIXTURES/capture_rate_limit.txt")"
  [ "$status" -eq 0 ]
  [ "$output" = "kind=rate_limit wait_seconds=45" ]
}

@test "detect_failure_signal returns kind=billing for billing credit exceeded" {
  run detect_failure_signal "$(cat "$FIXTURES/capture_billing.txt")"
  [ "$status" -eq 0 ]
  [ "$output" = "kind=billing" ]
}

@test "detect_failure_signal returns kind=none for healthy capture" {
  run detect_failure_signal "$(cat "$FIXTURES/capture_claude_idle.txt")"
  [ "$status" -eq 0 ]
  [ "$output" = "kind=none" ]
}

# ── is_pane_idle ────────────────────────────────────────────────────────────────

@test "is_pane_idle returns 0 when claude pane captures match and footer present" {
  local idle
  idle="$(cat "$FIXTURES/capture_claude_idle.txt")"
  run is_pane_idle "$idle" "$idle"
  [ "$status" -eq 0 ]
}

@test "is_pane_idle returns non-zero when captures differ (working)" {
  local idle working
  idle="$(cat "$FIXTURES/capture_claude_idle.txt")"
  working="$(cat "$FIXTURES/capture_claude_working.txt")"
  run is_pane_idle "$idle" "$working"
  [ "$status" -ne 0 ]
}

@test "is_pane_idle returns non-zero for dead pane (no footer)" {
  local dead
  dead="$(cat "$FIXTURES/capture_dead.txt")"
  run is_pane_idle "$dead" "$dead"
  [ "$status" -ne 0 ]
}

# ── is_pane_dead ────────────────────────────────────────────────────────────────

@test "is_pane_dead returns 0 when dead captures match and no footer" {
  local dead
  dead="$(cat "$FIXTURES/capture_dead.txt")"
  run is_pane_dead "$dead" "$dead"
  [ "$status" -eq 0 ]
}

@test "is_pane_dead returns non-zero when claude_idle captures match (has footer)" {
  local idle
  idle="$(cat "$FIXTURES/capture_claude_idle.txt")"
  run is_pane_dead "$idle" "$idle"
  [ "$status" -ne 0 ]
}

@test "is_pane_dead returns non-zero when captures differ (working vs idle)" {
  local idle working
  idle="$(cat "$FIXTURES/capture_claude_idle.txt")"
  working="$(cat "$FIXTURES/capture_claude_working.txt")"
  run is_pane_dead "$working" "$idle"
  [ "$status" -ne 0 ]
}

# ── extract_context_percent ─────────────────────────────────────────────────────

@test "extract_context_percent returns 72 for high ctx capture" {
  run extract_context_percent "$(cat "$FIXTURES/capture_claude_high_ctx.txt")"
  [ "$status" -eq 0 ]
  [ "$output" = "72" ]
}

@test "extract_context_percent returns 0 when no context indicator present" {
  run extract_context_percent "$(cat "$FIXTURES/capture_claude_idle.txt")"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

# ── Issue 1: rate.?limit and \b429\b ───────────────────────────────────────────

@test "detect_failure_signal handles rate-limit (dashed spelling)" {
  run detect_failure_signal "$(cat "$FIXTURES/capture_rate_limit_dashed.txt")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kind=rate_limit"* ]]
  [[ "$output" == *"wait_seconds=30"* ]]
}

@test "detect_failure_signal does not match bare 429 inside larger number" {
  run detect_failure_signal "found bug 4290 in code"
  [ "$status" -eq 0 ]
  [ "$output" = "kind=none" ]
}

# ── Issue 2: detect_footer_type anchored to tail ───────────────────────────────

@test "detect_footer_type ignores model name mentions in body text" {
  local cap
  cap="$(printf '사용자가 claude opus 4.7 좋다고 말했습니다.\n\n이건 본문이지 footer가 아닙니다.\n\n줄을 추가합니다.\n\n더 추가합니다.\n$ ls\npackage.json')"
  run detect_footer_type "$cap"
  [ "$status" -eq 0 ]
  [ "$output" = "none" ]
}

# ── Issue 3: multi-digit gpt version ──────────────────────────────────────────

@test "detect_footer_type recognizes multi-digit gpt version" {
  local cap
  cap="$(printf '작업 완료.\n\n›\ngpt-10  ·  ~/repo')"
  run detect_footer_type "$cap"
  [ "$status" -eq 0 ]
  [ "$output" = "codex" ]
}

# ── Issue 4: extract_context_percent caps >100 ────────────────────────────────

@test "extract_context_percent caps values over 100" {
  run extract_context_percent "claude opus 4.7  ·  ~/repo  ·  150% context used"
  [ "$status" -eq 0 ]
  [ "$output" = "100" ]
}

@test "extract_context_percent recognizes 100% boundary" {
  run extract_context_percent "claude opus 4.7  ·  ~/repo  ·  100% used"
  [ "$status" -eq 0 ]
  [ "$output" = "100" ]
}

#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../scripts/compact-or-fork.sh"
  TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# decide_action
# ---------------------------------------------------------------------------

@test "decide_action: returns none when pct < 60 (persistent)" {
  run decide_action 45 "persistent"
  [ "$status" -eq 0 ]
  [ "$output" = "none" ]
}

@test "decide_action: returns compact when 60 <= pct < 85 and lifecycle=persistent" {
  run decide_action 70 "persistent"
  [ "$status" -eq 0 ]
  [ "$output" = "compact" ]
}

@test "decide_action: returns fork when pct >= 85 (persistent)" {
  run decide_action 90 "persistent"
  [ "$status" -eq 0 ]
  [ "$output" = "fork" ]
}

@test "decide_action: returns fork when 60 <= pct < 85 and lifecycle=task-scoped" {
  run decide_action 70 "task-scoped"
  [ "$status" -eq 0 ]
  [ "$output" = "fork" ]
}

# ---------------------------------------------------------------------------
# manage_context (integration with mocked cmux)
# ---------------------------------------------------------------------------

@test "manage_context: calls /compact at 70% on persistent pane (mock cmux)" {
  export MANIFEST_PATH="$TMPDIR/manifest.json"
  export CMUX_LOG="$TMPDIR/cmux.log"

  # Build mock cmux binary: capture-pane returns the 72% fixture; other cmds are logged
  cat > "$TMPDIR/cmux" <<SH
#!/usr/bin/env bash
case "\$1" in
  capture-pane) cat "$BATS_TEST_DIRNAME/../fixtures/capture_claude_high_ctx.txt" ;;
  *) echo "\$@" >> "$CMUX_LOG" ;;
esac
SH
  chmod +x "$TMPDIR/cmux"
  export CMUX_BIN="$TMPDIR/cmux"

  # Manifest: persistent pane on surface:5
  cat > "$MANIFEST_PATH" <<'EOF'
{ "panes": { "surface:5": { "role": "plan", "model": "claude", "lifecycle": "persistent" } }, "stages": {} }
EOF

  run manage_context "surface:5"
  [ "$status" -eq 0 ]

  run cat "$CMUX_LOG"
  echo "$output" | grep -q "send --surface surface:5 /compact"
}

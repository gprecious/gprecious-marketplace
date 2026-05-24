#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  export CMUX_LOG="$TMPDIR/cmux_calls.log"
  cat > "$TMPDIR/cmux" <<'SH'
#!/usr/bin/env bash
echo "$@" >> "$CMUX_LOG"
SH
  chmod +x "$TMPDIR/cmux"
  export CMUX_BIN="$TMPDIR/cmux"
  source "$BATS_TEST_DIRNAME/../../scripts/send-and-poll.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# send_text_with_enter
# ---------------------------------------------------------------------------

@test "send_text_with_enter: calls send then send-key Enter with correct surface" {
  send_text_with_enter "surface:5" "hello world"
  run cat "$CMUX_LOG"
  echo "$output" | grep -q "send --surface surface:5 hello world"
  echo "$output" | grep -q "send-key --surface surface:5 Enter"
}

@test "send_text_with_enter: send is called once even for multi-word text" {
  send_text_with_enter "surface:3" "line1 line2"
  local count
  count=$(grep -c "^send --surface" "$CMUX_LOG")
  [ "$count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# cmux_capture
# ---------------------------------------------------------------------------

@test "cmux_capture: uses default 60 lines when no second arg" {
  cmux_capture "surface:7"
  run cat "$CMUX_LOG"
  echo "$output" | grep -q "capture-pane --surface surface:7 --lines 60"
}

@test "cmux_capture: passes custom lines when given as second arg" {
  cmux_capture "surface:2" 120
  run cat "$CMUX_LOG"
  echo "$output" | grep -q "capture-pane --surface surface:2 --lines 120"
}

# ---------------------------------------------------------------------------
# poll_until_idle
# ---------------------------------------------------------------------------

@test "poll_until_idle: exits 0 when two consecutive captures match (mock provider)" {
  # Three paragraphs (blank-line delimited): sections 2 and 3 are identical
  # so the second consecutive match triggers idle detection.
  cat > "$TMPDIR/seq.txt" <<'EOF'
working...

done
❯
claude opus 4.7  ·  ~/repo

done
❯
claude opus 4.7  ·  ~/repo
EOF
  capture_provider() {
    local n; n=$(cat "$TMPDIR/poll_idx" 2>/dev/null || echo 0)
    awk -v section=$((n+1)) 'BEGIN{RS=""} NR==section' "$TMPDIR/seq.txt"
    echo $((n+1)) > "$TMPDIR/poll_idx"
  }
  export -f capture_provider
  run poll_until_idle capture_provider 0 5
  [ "$status" -eq 0 ]
}

@test "poll_until_idle: exits non-zero on max iterations" {
  capture_provider() { echo "still working $(date +%N)"; }
  export -f capture_provider
  run poll_until_idle capture_provider 0 3
  [ "$status" -ne 0 ]
}

@test "poll_until_idle: echoes matched capture to stdout on idle" {
  # Sections 2 and 3 are identical; section 1 differs to ensure we skip it.
  cat > "$TMPDIR/seq2.txt" <<'EOF'
running task

idle output
❯

idle output
❯
EOF
  capture_provider2() {
    local n; n=$(cat "$TMPDIR/poll_idx2" 2>/dev/null || echo 0)
    awk -v section=$((n+1)) 'BEGIN{RS=""} NR==section' "$TMPDIR/seq2.txt"
    echo $((n+1)) > "$TMPDIR/poll_idx2"
  }
  export -f capture_provider2
  run poll_until_idle capture_provider2 0 5
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "idle output"
}

#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  export MANIFEST_PATH="$TMPDIR/manifest.json"
  source "$BATS_TEST_DIRNAME/../../scripts/manifest.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

# ── manifest_init ──────────────────────────────────────────────────────────────

@test "manifest_init creates a valid JSON file" {
  manifest_init "feature-x" "test description" "claude"
  [ -f "$MANIFEST_PATH" ]
  run jq empty "$MANIFEST_PATH"
  [ "$status" -eq 0 ]
}

@test "manifest_init sets feature_slug, task_description, schema_version, status" {
  manifest_init "feature-x" "test description" "claude"
  run jq -r '.feature_slug' "$MANIFEST_PATH"
  [ "$status" -eq 0 ]
  [ "$output" = "feature-x" ]

  run jq -r '.task_description' "$MANIFEST_PATH"
  [ "$output" = "test description" ]

  run jq -r '.schema_version' "$MANIFEST_PATH"
  [ "$output" = "1" ]

  run jq -r '.status' "$MANIFEST_PATH"
  [ "$output" = "in_progress" ]
}

@test "manifest_init creates empty stages/panes objects and empty acceptance_criteria array" {
  manifest_init "feature-x" "test description" "claude"
  run jq -r '.stages | type' "$MANIFEST_PATH"
  [ "$output" = "object" ]
  run jq -r '.stages | length' "$MANIFEST_PATH"
  [ "$output" = "0" ]

  run jq -r '.panes | type' "$MANIFEST_PATH"
  [ "$output" = "object" ]

  run jq -r '.acceptance_criteria | type' "$MANIFEST_PATH"
  [ "$output" = "array" ]
  run jq -r '.acceptance_criteria | length' "$MANIFEST_PATH"
  [ "$output" = "0" ]
}

# ── manifest_set_stage ─────────────────────────────────────────────────────────

@test "manifest_set_stage creates stage when absent and sets all fields" {
  manifest_init "feature-x" "desc" "claude"
  manifest_set_stage "planning" status=pending priority=high
  run jq -r '.stages.planning.status' "$MANIFEST_PATH"
  [ "$output" = "pending" ]
  run jq -r '.stages.planning.priority' "$MANIFEST_PATH"
  [ "$output" = "high" ]
}

@test "manifest_set_stage merges into existing stage without dropping other fields" {
  manifest_init "feature-x" "desc" "claude"
  manifest_set_stage "planning" status=pending priority=high
  manifest_set_stage "planning" status=done
  run jq -r '.stages.planning.status' "$MANIFEST_PATH"
  [ "$output" = "done" ]
  run jq -r '.stages.planning.priority' "$MANIFEST_PATH"
  [ "$output" = "high" ]
}

@test "manifest_set_stage updates last_updated on every call" {
  manifest_init "feature-x" "desc" "claude"
  manifest_set_stage "planning" status=pending
  local ts1
  ts1=$(jq -r '.last_updated' "$MANIFEST_PATH")
  sleep 1
  manifest_set_stage "planning" status=done
  local ts2
  ts2=$(jq -r '.last_updated' "$MANIFEST_PATH")
  [ "$ts1" != "$ts2" ]
}

# ── manifest_get_stage_field ───────────────────────────────────────────────────

@test "manifest_get_stage_field returns value when stage and field exist" {
  manifest_init "feature-x" "desc" "claude"
  manifest_set_stage "coding" status=in_progress
  run manifest_get_stage_field "coding" "status"
  [ "$status" -eq 0 ]
  [ "$output" = "in_progress" ]
}

@test "manifest_get_stage_field returns empty when stage missing" {
  manifest_init "feature-x" "desc" "claude"
  run manifest_get_stage_field "nonexistent" "status"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "manifest_get_stage_field returns empty when field missing" {
  manifest_init "feature-x" "desc" "claude"
  manifest_set_stage "coding" status=in_progress
  run manifest_get_stage_field "coding" "nonexistent_field"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

# ── manifest_list_stages_by_status ─────────────────────────────────────────────

@test "manifest_list_stages_by_status returns matching stage names" {
  manifest_init "feature-x" "desc" "claude"
  manifest_set_stage "planning" status=done
  manifest_set_stage "coding" status=in_progress
  manifest_set_stage "review" status=done
  run manifest_list_stages_by_status "done"
  [ "$status" -eq 0 ]
  # output is space-separated; check both expected names present
  [[ "$output" == *"planning"* ]]
  [[ "$output" == *"review"* ]]
  # coding should NOT be in the output
  [[ "$output" != *"coding"* ]]
}

# ── manifest_record_pane ───────────────────────────────────────────────────────

@test "manifest_record_pane stores pane info with all fields and alive=true" {
  manifest_init "feature-x" "desc" "claude"
  manifest_record_pane "left:0" "worker" "sonnet" "session"
  run jq -r '.panes["left:0"].role' "$MANIFEST_PATH"
  [ "$output" = "worker" ]
  run jq -r '.panes["left:0"].model' "$MANIFEST_PATH"
  [ "$output" = "sonnet" ]
  run jq -r '.panes["left:0"].lifecycle' "$MANIFEST_PATH"
  [ "$output" = "session" ]
  run jq -r '.panes["left:0"].alive' "$MANIFEST_PATH"
  [ "$output" = "true" ]
  run jq -r '.panes["left:0"].spawned_at' "$MANIFEST_PATH"
  [ "$output" != "null" ]
  [ "$output" != "" ]
}

# ── manifest_pane_for_role ─────────────────────────────────────────────────────

@test "manifest_pane_for_role returns surface ref for matching alive pane" {
  manifest_init "feature-x" "desc" "claude"
  manifest_record_pane "left:0" "worker" "sonnet" "session"
  manifest_record_pane "right:1" "reviewer" "opus" "session"
  run manifest_pane_for_role "worker"
  [ "$status" -eq 0 ]
  [ "$output" = "left:0" ]
}

@test "manifest_pane_for_role returns empty string when no match" {
  manifest_init "feature-x" "desc" "claude"
  manifest_record_pane "left:0" "worker" "sonnet" "session"
  run manifest_pane_for_role "orchestrator"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

# ── manifest_set_classification ────────────────────────────────────────────────

@test "manifest_set_classification updates task_classification field" {
  manifest_init "feature-x" "desc" "claude"
  manifest_set_classification "greenfield"
  run jq -r '.task_classification' "$MANIFEST_PATH"
  [ "$output" = "greenfield" ]
}

# ── manifest_set_acceptance_criteria ──────────────────────────────────────────

@test "manifest_record_pane updates last_updated timestamp" {
  manifest_init "feature-x" "desc" "claude"
  local before
  before=$(jq -r '.last_updated' "$MANIFEST_PATH")
  sleep 1
  manifest_record_pane "surface:1" "plan" "sonnet" "session"
  local after
  after=$(jq -r '.last_updated' "$MANIFEST_PATH")
  [ "$after" != "$before" ]
}

@test "manifest_pane_for_role skips dead panes and returns alive one" {
  manifest_init "feature-x" "desc" "claude"
  manifest_record_pane "surface:1" "plan" "sonnet" "session"
  manifest_record_pane "surface:2" "plan" "sonnet" "session"
  jq '.panes."surface:1".alive = false' "$MANIFEST_PATH" > "$TMPDIR/tmp.json" && mv "$TMPDIR/tmp.json" "$MANIFEST_PATH"
  run manifest_pane_for_role "plan"
  [ "$status" -eq 0 ]
  [ "$output" = "surface:2" ]
}

@test "manifest_set_stage handles values containing equals signs" {
  manifest_init "f" "d" "claude"
  manifest_set_stage "plan" "evidence=a=b=c" "url=http://x?y=1&z=2"
  run jq -r '.stages.plan.evidence' "$MANIFEST_PATH"
  [ "$output" = "a=b=c" ]
  run jq -r '.stages.plan.url' "$MANIFEST_PATH"
  [ "$output" = "http://x?y=1&z=2" ]
}

@test "manifest_set_acceptance_criteria replaces AC list from JSON file" {
  manifest_init "feature-x" "desc" "claude"
  local ac_file="$TMPDIR/ac.json"
  cat > "$ac_file" <<'EOF'
[
  {"id": "AC-001", "description": "First criterion"},
  {"id": "AC-002", "description": "Second criterion"},
  {"id": "AC-003", "description": "Third criterion"}
]
EOF
  manifest_set_acceptance_criteria "$ac_file"
  run jq -r '.acceptance_criteria | length' "$MANIFEST_PATH"
  [ "$output" = "3" ]
  run jq -r '.acceptance_criteria[0].id' "$MANIFEST_PATH"
  [ "$output" = "AC-001" ]
}

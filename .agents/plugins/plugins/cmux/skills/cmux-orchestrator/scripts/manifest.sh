#!/usr/bin/env bash
# manifest.sh — cmux-orchestrator manifest.json helpers
# All functions read/write env var MANIFEST_PATH
set -euo pipefail

# ── manifest_init ──────────────────────────────────────────────────────────────
# manifest_init <slug> <description> <orchestrator_model>
# Creates a fresh manifest.json at $MANIFEST_PATH.
manifest_init() {
  local slug="$1"
  local description="$2"
  local orchestrator_model="${3:-claude}"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -n \
    --arg slug "$slug" \
    --arg desc "$description" \
    --arg now "$now" \
    --arg model "$orchestrator_model" \
    '{
      schema_version: 1,
      feature_slug: $slug,
      task_description: $desc,
      task_classification: "unknown",
      started_at: $now,
      last_updated: $now,
      status: "in_progress",
      workspace_id: null,
      visualization_command: null,
      orchestrator_model: $model,
      panes: {},
      acceptance_criteria: [],
      stages: {},
      design_verification: null
    }' > "$MANIFEST_PATH"
}

# ── manifest_set_stage ─────────────────────────────────────────────────────────
# manifest_set_stage <stage_name> [key=value]...
# Updates stages.<stage_name> with given key=value pairs.
# Creates stage if absent. Always updates last_updated.
manifest_set_stage() {
  local stage_name="$1"
  shift
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Build a JSON object from the key=value pairs
  local kv_json="{}"
  for pair in "$@"; do
    local key="${pair%%=*}"
    local val="${pair#*=}"
    kv_json="$(jq -n --argjson base "$kv_json" --arg k "$key" --arg v "$val" '$base + {($k): $v}')"
  done

  local tmp
  tmp="$(mktemp)"
  jq \
    --arg stage "$stage_name" \
    --arg now "$now" \
    --argjson kv "$kv_json" \
    '.stages[$stage] = ((.stages[$stage] // {}) + $kv) | .last_updated = $now' \
    "$MANIFEST_PATH" > "$tmp" && mv "$tmp" "$MANIFEST_PATH"
}

# ── manifest_get_stage_field ───────────────────────────────────────────────────
# manifest_get_stage_field <stage_name> <field_name>
# Returns the field value from stages.<stage_name>.<field_name>, or empty string.
manifest_get_stage_field() {
  local stage_name="$1"
  local field_name="$2"
  local val
  val="$(jq -r --arg stage "$stage_name" --arg field "$field_name" \
    '(.stages[$stage] // {}) | .[$field] // empty' \
    "$MANIFEST_PATH")"
  echo "$val"
}

# ── manifest_list_stages_by_status ─────────────────────────────────────────────
# manifest_list_stages_by_status <status>
# Echoes a space-separated list of stage names whose .status matches.
manifest_list_stages_by_status() {
  local target_status="$1"
  local names
  names="$(jq -r --arg s "$target_status" \
    '[.stages | to_entries[] | select(.value.status == $s) | .key] | join(" ")' \
    "$MANIFEST_PATH")"
  echo "$names"
}

# ── manifest_record_pane ───────────────────────────────────────────────────────
# manifest_record_pane <surface_ref> <role> <model> <lifecycle>
# Stores pane info under panes[<surface_ref>].
manifest_record_pane() {
  local surface_ref="$1"
  local role="$2"
  local model="$3"
  local lifecycle="$4"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local tmp
  tmp="$(mktemp)"
  jq \
    --arg ref "$surface_ref" \
    --arg role "$role" \
    --arg model "$model" \
    --arg lifecycle "$lifecycle" \
    --arg now "$now" \
    '.panes[$ref] = {
      role: $role,
      model: $model,
      lifecycle: $lifecycle,
      spawned_at: $now,
      alive_check_at: $now,
      alive: true
    } | .last_updated = $now' \
    "$MANIFEST_PATH" > "$tmp" && mv "$tmp" "$MANIFEST_PATH"
}

# ── manifest_pane_for_role ─────────────────────────────────────────────────────
# manifest_pane_for_role <role>
# Returns the surface ref of the first alive pane matching the role.
# Empty string if none.
manifest_pane_for_role() {
  local role="$1"
  local ref
  ref="$(jq -r --arg role "$role" \
    '[.panes | to_entries[] | select(.value.role == $role and .value.alive == true) | .key] | first // empty' \
    "$MANIFEST_PATH")"
  echo "$ref"
}

# ── manifest_set_classification ────────────────────────────────────────────────
# manifest_set_classification <classification>
# Sets .task_classification, updates last_updated.
manifest_set_classification() {
  local classification="$1"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local tmp
  tmp="$(mktemp)"
  jq \
    --arg c "$classification" \
    --arg now "$now" \
    '.task_classification = $c | .last_updated = $now' \
    "$MANIFEST_PATH" > "$tmp" && mv "$tmp" "$MANIFEST_PATH"
}

# ── manifest_set_acceptance_criteria ──────────────────────────────────────────
# manifest_set_acceptance_criteria <json_file>
# Replaces .acceptance_criteria with the array from the given JSON file.
manifest_set_acceptance_criteria() {
  local json_file="$1"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local tmp
  tmp="$(mktemp)"
  jq \
    --slurpfile ac "$json_file" \
    --arg now "$now" \
    '.acceptance_criteria = $ac[0] | .last_updated = $now' \
    "$MANIFEST_PATH" > "$tmp" && mv "$tmp" "$MANIFEST_PATH"
}

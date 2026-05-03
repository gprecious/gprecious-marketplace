#!/usr/bin/env bash
# compact-or-fork.sh — cmux-orchestrator context management
# Source this file; do not execute directly.
set -euo pipefail

# ── decide_action ───────────────────────────────────────────────────────────────
# decide_action <context_percent> <lifecycle>
# Echoes one of: none / compact / fork
#
# Rules:
#   pct < 60                              → none
#   pct >= 85                             → fork  (regardless of lifecycle)
#   60 <= pct < 85, lifecycle=persistent  → compact
#   60 <= pct < 85, lifecycle=task-scoped → fork  (compact useless, closing soon)
decide_action() {
  local pct="$1"
  local lifecycle="$2"

  if [ "$pct" -lt 60 ]; then
    echo "none"
    return
  fi

  if [ "$pct" -ge 85 ]; then
    echo "fork"
    return
  fi

  # 60 <= pct < 85
  if [ "$lifecycle" = "persistent" ]; then
    echo "compact"
    return
  fi

  echo "fork"
}

# ── manage_context ──────────────────────────────────────────────────────────────
# manage_context <surface_ref>
#
# Reads context usage from the pane, looks up lifecycle in the manifest,
# decides what to do, and acts:
#   none    → return 0
#   compact → send /compact to the pane; return 0
#   fork    → echo "fork:role=<role>:artifact=<path>" to stderr; return 10
manage_context() {
  local surface="$1"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # shellcheck source=./pane-status.sh
  source "$script_dir/pane-status.sh"
  # shellcheck source=./send-and-poll.sh
  source "$script_dir/send-and-poll.sh"
  # shellcheck source=./manifest.sh
  source "$script_dir/manifest.sh"

  local cap pct lifecycle action

  cap="$(cmux_capture "$surface" 80)"
  pct="$(extract_context_percent "$cap")"
  lifecycle="$(jq -r --arg s "$surface" '.panes[$s].lifecycle // ""' "$MANIFEST_PATH")"
  action="$(decide_action "$pct" "$lifecycle")"

  case "$action" in
    none)
      return 0
      ;;
    compact)
      send_text_with_enter "$surface" "/compact"
      return 0
      ;;
    fork)
      local role artifact
      role="$(jq -r --arg s "$surface" '.panes[$s].role // ""' "$MANIFEST_PATH")"
      artifact="$(jq -r --arg r "$role" '.stages[$r].artifact // ""' "$MANIFEST_PATH")"
      echo "fork:role=$role:artifact=$artifact" >&2
      return 10
      ;;
  esac
}

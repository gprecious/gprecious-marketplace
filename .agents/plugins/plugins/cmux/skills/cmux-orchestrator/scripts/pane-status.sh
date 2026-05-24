#!/usr/bin/env bash
# pane-status.sh — cmux-orchestrator pane capture analysis helpers
# Source this file; do not execute directly.
set -euo pipefail

# ── detect_footer_type ──────────────────────────────────────────────────────────
# detect_footer_type <capture_text>
# Echoes "claude" / "codex" / "none" based on footer line in capture.
detect_footer_type() {
  local capture="$1"
  local tail
  tail="$(echo "$capture" | tail -5)"
  if echo "$tail" | grep -qE 'claude (opus|sonnet|haiku) [0-9]'; then
    echo "claude"
    return
  fi
  if echo "$tail" | grep -qE 'gpt-[0-9]+(\.[0-9]+)?\b'; then
    echo "codex"
    return
  fi
  echo "none"
}

# ── detect_failure_signal ───────────────────────────────────────────────────────
# detect_failure_signal <capture_text>
# Echoes:
#   kind=rate_limit wait_seconds=<N>   (rate limit with parseable wait time)
#   kind=rate_limit                    (rate limit without parseable wait time)
#   kind=billing                       (billing/credit exceeded)
#   kind=none                          (no failure signal)
detect_failure_signal() {
  local capture="$1"

  # Rate limit check (must come before billing to avoid ambiguity)
  if echo "$capture" | grep -qiE 'rate.?limit|\b429\b'; then
    local wait_seconds
    # Try to parse "Try again in N seconds" (or "in N second")
    wait_seconds="$(echo "$capture" | grep -oiE 'Try again in [0-9]+ seconds?' | grep -oE '[0-9]+' | head -1)" || true
    if [ -n "$wait_seconds" ]; then
      echo "kind=rate_limit wait_seconds=$wait_seconds"
    else
      echo "kind=rate_limit"
    fi
    return
  fi

  # Billing check
  if echo "$capture" | grep -qiE 'billing|credit (exceeded|exhausted)'; then
    echo "kind=billing"
    return
  fi

  echo "kind=none"
}

# ── is_pane_idle ────────────────────────────────────────────────────────────────
# is_pane_idle <prev_capture> <curr_capture>
# Returns 0 if pane is idle (captures match AND footer present), non-zero otherwise.
#   exit 1 → captures differ (still working)
#   exit 2 → captures match but no footer (dead shell, not idle AI)
#   exit 0 → idle
is_pane_idle() {
  local prev="$1"
  local curr="$2"

  if [ "$prev" != "$curr" ]; then
    return 1
  fi

  local footer_type
  footer_type="$(detect_footer_type "$curr")"
  if [ "$footer_type" = "none" ]; then
    return 2
  fi

  return 0
}

# ── is_pane_dead ────────────────────────────────────────────────────────────────
# is_pane_dead <prev_capture> <curr_capture>
# Returns 0 if pane is dead (captures match AND no footer), non-zero otherwise.
#   exit 1 → captures differ (still changing)
#   exit 2 → captures match but footer present (AI idle, not dead)
#   exit 0 → dead
is_pane_dead() {
  local prev="$1"
  local curr="$2"

  if [ "$prev" != "$curr" ]; then
    return 1
  fi

  local footer_type
  footer_type="$(detect_footer_type "$curr")"
  if [ "$footer_type" != "none" ]; then
    return 2
  fi

  return 0
}

# ── extract_context_percent ─────────────────────────────────────────────────────
# extract_context_percent <capture_text>
# Echoes integer 0-100 representing context usage percentage.
# Returns 0 if no context indicator is found.
extract_context_percent() {
  local capture="$1"
  local pct

  # Match patterns like: "72% context used", "72% of context", "72% used"
  pct="$(echo "$capture" | grep -oE '[0-9]{1,3}% (context )?(used|of context)' | head -1 | grep -oE '^[0-9]+' || true)"
  pct="${pct:-0}"
  if [ "$pct" -gt 100 ]; then pct=100; fi
  echo "$pct"
}

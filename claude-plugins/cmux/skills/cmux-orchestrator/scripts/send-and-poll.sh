#!/usr/bin/env bash
set -euo pipefail

CMUX_BIN="${CMUX_BIN:-cmux}"

# send_text_with_enter <surface_ref> <text>
#
# Wraps cmux send + send-key Enter as an atomic pair.
#
# The cmux pitfall: `cmux send` queues text into the pane but does NOT submit
# it until `cmux send-key Enter` is called. This function ensures the two calls
# always travel together so callers cannot accidentally omit the Enter.
#
# NOTE: <text> is captured via "$*" (all remaining args joined by IFS space).
# For multi-line content pass a single quoted argument, e.g.:
#   send_text_with_enter "surface:1" "$(cat <<'EOF'
#   line1
#   line2
#   EOF
#   )"
send_text_with_enter() {
  local surface="$1"; shift
  local text="$*"
  "$CMUX_BIN" send --surface "$surface" "$text"
  "$CMUX_BIN" send-key --surface "$surface" Enter
}

# cmux_capture <surface_ref> [lines]
#
# Captures the last <lines> lines of the pane identified by <surface_ref>.
# Defaults to 60 lines — enough for most prompt footers without excessive noise.
cmux_capture() {
  local surface="$1"
  local lines="${2:-60}"
  "$CMUX_BIN" capture-pane --surface "$surface" --lines "$lines"
}

# poll_until_idle <capture_provider_fn> [sleep_seconds] [max_iters]
#
# Polls the pane via <capture_provider_fn> until output stabilises (two
# consecutive captures are identical) or the iteration budget is exhausted.
#
# Arguments:
#   capture_provider_fn  — name of a function (or exported bash function) that
#                          prints the current pane capture to stdout.
#   sleep_seconds        — seconds to sleep between polls. Default: 3.
#                          Pass 0 for tests to avoid real delays.
#   max_iters            — maximum number of iterations before giving up.
#                          Default: 20.
#
# Returns:
#   0  — idle state reached; matched capture echoed to stdout.
#   1  — iteration budget exhausted; last seen capture echoed to stderr.
poll_until_idle() {
  local provider_fn="$1"
  local sleep_s="${2:-3}"
  local max_iters="${3:-20}"
  local prev=""
  local i=0

  while [ "$i" -lt "$max_iters" ]; do
    [ "$sleep_s" -gt 0 ] && sleep "$sleep_s"
    local curr
    curr="$("$provider_fn")"
    if [ -n "$prev" ] && [ "$prev" = "$curr" ]; then
      echo "$curr"
      return 0
    fi
    prev="$curr"
    i=$((i + 1))
  done

  echo "$prev" >&2
  return 1
}

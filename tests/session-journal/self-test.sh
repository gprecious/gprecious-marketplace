#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
VAULT="${TMP_DIR}/vault"
STATE="${TMP_DIR}/state"

cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

export LLM_OBSIDIAN_VAULT="${VAULT}"
export SESSION_JOURNAL_STATE="${STATE}"
export SESSION_JOURNAL_CORE="${ROOT}/shared/session-journal/session_journal_core.py"

CODEX_PLUGIN_ROOT="${ROOT}/.agents/plugins/plugins/session-journal"
CLAUDE_PLUGIN_ROOT="${ROOT}/claude-plugins/session-journal"
CODEX_HOOK="${CODEX_PLUGIN_ROOT}/hooks/session_journal_hook.py"
CLAUDE_HOOK="${CLAUDE_PLUGIN_ROOT}/hooks/session_journal_hook.py"
WORK="/Users/dev/gprecious-marketplace"   # a non-tmp (meaningful) workspace path

# --- meaningful Codex session (real workspace, prompt + tools + result) ---
env PLUGIN_ROOT="${CODEX_PLUGIN_ROOT}" python3 "${CODEX_HOOK}" hook --agent "Codex" <<JSON >/dev/null
{ "session_id": "codex-self-test", "hook_event_name": "SessionStart", "cwd": "${WORK}", "source": "startup", "model": "gpt-5" }
JSON
env PLUGIN_ROOT="${CODEX_PLUGIN_ROOT}" python3 "${CODEX_HOOK}" hook --agent "Codex" <<JSON >/dev/null
{ "session_id": "codex-self-test", "hook_event_name": "UserPromptSubmit", "cwd": "${WORK}", "turn_id": "t1", "prompt": "Record this. Link [[research-engine]], [[dream]], [[evolve]]." }
JSON
env PLUGIN_ROOT="${CODEX_PLUGIN_ROOT}" python3 "${CODEX_HOOK}" hook --agent "Codex" <<JSON >/dev/null
{ "session_id": "codex-self-test", "hook_event_name": "PostToolUse", "cwd": "${WORK}", "tool_name": "Bash", "tool_input": { "command": "echo hi # this verbatim line must NOT appear" } }
JSON
env PLUGIN_ROOT="${CODEX_PLUGIN_ROOT}" python3 "${CODEX_HOOK}" hook --agent "Codex" <<JSON >/dev/null
{ "session_id": "codex-self-test", "hook_event_name": "Stop", "cwd": "${WORK}", "turn_id": "t1", "stop_hook_active": false, "last_assistant_message": "Done. resolved: this whole line must NOT become a durable note." }
JSON

# --- trivial session (tmp cwd, no real prompt) → must be SKIPPED ---
env CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}" python3 "${CLAUDE_HOOK}" hook --agent "Claude Code" <<JSON >/dev/null
{ "session_id": "trivial-self-test", "hook_event_name": "SessionStart", "cwd": "/tmp/scratch", "source": "startup" }
JSON
env CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}" python3 "${CLAUDE_HOOK}" hook --agent "Claude Code" <<JSON >/dev/null
{ "session_id": "trivial-self-test", "hook_event_name": "Stop", "cwd": "/tmp/scratch", "stop_hook_active": false, "last_assistant_message": "ok" }
JSON

DATE="$(date +%Y-%m-%d)"
DAILY="${VAULT}/Journal/${DATE}.md"

# 1. Daily note exists and is the ONLY journal note shape (no per-session files).
test -f "${DAILY}"
test ! -d "${VAULT}/Sessions"

# 2. Raw lives OUTSIDE the vault, under the state root.
test ! -d "${VAULT}/Raw"
CODEX_RAW="$(find "${STATE}/Raw" -name 'codex-self-test.jsonl' -print -quit)"
test -f "${CODEX_RAW}"
test "$(wc -l < "${CODEX_RAW}" | tr -d ' ')" -ge 4

# 3. Meaningful session is in the daily note with wikilinks for the graph.
grep -q '<!-- session:codex-self-test:start -->' "${DAILY}"
grep -q '\[\[research-engine\]\]' "${DAILY}"
grep -q '\[\[Codex\]\]' "${DAILY}"

# 4. Trivial session is NOT listed.
if grep -q 'trivial-self-test' "${DAILY}"; then
  echo "FAIL: trivial session leaked into the daily note" >&2; exit 1
fi

# 5. No verbatim transcript / tool command / auto-wiki leakage.
if grep -q 'this verbatim line must NOT' "${DAILY}"; then
  echo "FAIL: verbatim tool command copied into the note" >&2; exit 1
fi
if [ -d "${VAULT}/Wiki" ]; then
  echo "FAIL: auto-generated Wiki/ folder created" >&2; exit 1
fi

# 6. Re-running the meaningful session's Stop upserts (does NOT duplicate) its block.
env PLUGIN_ROOT="${CODEX_PLUGIN_ROOT}" python3 "${CODEX_HOOK}" hook --agent "Codex" <<JSON >/dev/null
{ "session_id": "codex-self-test", "hook_event_name": "Stop", "cwd": "${WORK}", "turn_id": "t2", "stop_hook_active": false, "last_assistant_message": "Second turn." }
JSON
COUNT="$(grep -c '<!-- session:codex-self-test:start -->' "${DAILY}")"
test "${COUNT}" -eq 1

# 7. Manual summarize still works against the external raw + daily note.
python3 "${ROOT}/shared/session-journal/session_journal_core.py" summarize --vault "${VAULT}" --session-id codex-self-test >/tmp/session-journal-summary.json
grep -q "daily_note" /tmp/session-journal-summary.json

echo "session-journal self-test passed: vault=${VAULT} state=${STATE}"

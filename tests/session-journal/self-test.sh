#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
VAULT="${TMP_DIR}/vault"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

export LLM_OBSIDIAN_VAULT="${VAULT}"
export SESSION_JOURNAL_CORE="${ROOT}/shared/session-journal/session_journal_core.py"

CODEX_PLUGIN_ROOT="${ROOT}/.agents/plugins/plugins/session-journal"
CLAUDE_PLUGIN_ROOT="${ROOT}/claude-plugins/session-journal"

env PLUGIN_ROOT="${CODEX_PLUGIN_ROOT}" python3 "${CODEX_PLUGIN_ROOT}/hooks/session_journal_hook.py" hook --agent "Codex" <<'JSON' >/tmp/session-journal-codex-start.json
{
  "session_id": "codex-self-test",
  "hook_event_name": "SessionStart",
  "cwd": "/tmp/gprecious-marketplace",
  "source": "startup",
  "model": "gpt-5"
}
JSON

env PLUGIN_ROOT="${CODEX_PLUGIN_ROOT}" python3 "${CODEX_PLUGIN_ROOT}/hooks/session_journal_hook.py" hook --agent "Codex" <<'JSON' >/tmp/session-journal-codex-prompt.json
{
  "session_id": "codex-self-test",
  "hook_event_name": "UserPromptSubmit",
  "cwd": "/tmp/gprecious-marketplace",
  "turn_id": "turn-1",
  "prompt": "Record this prompt. integration: Link [[research-engine]], [[dream]], and [[evolve]] from the Obsidian graph."
}
JSON

env PLUGIN_ROOT="${CODEX_PLUGIN_ROOT}" python3 "${CODEX_PLUGIN_ROOT}/hooks/session_journal_hook.py" hook --agent "Codex" <<'JSON' >/tmp/session-journal-codex-stop.json
{
  "session_id": "codex-self-test",
  "hook_event_name": "Stop",
  "cwd": "/tmp/gprecious-marketplace",
  "turn_id": "turn-1",
  "stop_hook_active": false,
  "last_assistant_message": "Finished synthetic Codex work. pattern: Shared hook core creates Obsidian session summaries and durable wiki notes."
}
JSON

env CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}" python3 "${CLAUDE_PLUGIN_ROOT}/hooks/session_journal_hook.py" hook --agent "Claude Code" <<'JSON' >/tmp/session-journal-claude-prompt.json
{
  "session_id": "claude-self-test",
  "hook_event_name": "UserPromptSubmit",
  "cwd": "/tmp/gprecious-marketplace",
  "prompt": "Record this Claude prompt. convention: Raw events are append-only and summaries are regenerated."
}
JSON

env CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}" python3 "${CLAUDE_PLUGIN_ROOT}/hooks/session_journal_hook.py" hook --agent "Claude Code" <<'JSON' >/tmp/session-journal-claude-stop.json
{
  "session_id": "claude-self-test",
  "hook_event_name": "Stop",
  "cwd": "/tmp/gprecious-marketplace",
  "stop_hook_active": false,
  "last_assistant_message": "Finished synthetic Claude work. resolved: Claude Code hook output created a wiki note."
}
JSON

CODEX_SESSION="$(find "${VAULT}/Sessions" -name 'codex-self-test.md' -print -quit)"
CLAUDE_SESSION="$(find "${VAULT}/Sessions" -name 'claude-self-test.md' -print -quit)"
CODEX_RAW="$(find "${VAULT}/Raw" -name 'codex-self-test.jsonl' -print -quit)"
CLAUDE_RAW="$(find "${VAULT}/Raw" -name 'claude-self-test.jsonl' -print -quit)"

test -f "${CODEX_SESSION}"
test -f "${CLAUDE_SESSION}"
test -f "${CODEX_RAW}"
test -f "${CLAUDE_RAW}"

grep -q "User Prompt" "${CODEX_SESSION}"
grep -q "Agent Result" "${CODEX_SESSION}"
grep -q "Current Summary" "${CODEX_SESSION}"
grep -q '\[\[research-engine\]\]' "${CODEX_SESSION}"
grep -q '\[\[dream\]\]' "${CODEX_SESSION}"
grep -q '\[\[evolve\]\]' "${CODEX_SESSION}"
grep -q "User Prompt" "${CLAUDE_SESSION}"
grep -q "Agent Result" "${CLAUDE_SESSION}"
grep -q "Current Summary" "${CLAUDE_SESSION}"
grep -q '\[\[Claude Code\]\]' "${CLAUDE_SESSION}"
grep -q '\[\[Codex\]\]' "${CLAUDE_SESSION}"

test "$(wc -l < "${CODEX_RAW}" | tr -d ' ')" -ge 3
test "$(wc -l < "${CLAUDE_RAW}" | tr -d ' ')" -ge 2

find "${VAULT}/Wiki" -type f -name '*.md' | grep -q .
grep -R -q '\[\[research-engine\]\]' "${VAULT}/Wiki"
grep -R -q '\[\[herdr\]\]' "${VAULT}/Wiki"

python3 "${ROOT}/shared/session-journal/session_journal_core.py" summarize --vault "${VAULT}" --session-id codex-self-test >/tmp/session-journal-summary.json
grep -q "session_note" /tmp/session-journal-summary.json

echo "session-journal self-test passed: ${VAULT}"

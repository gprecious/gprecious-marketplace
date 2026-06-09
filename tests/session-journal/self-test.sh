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
  "prompt": "Record this prompt. Link [[research-engine]], [[dream]], and [[evolve]] from the Obsidian graph."
}
JSON

env PLUGIN_ROOT="${CODEX_PLUGIN_ROOT}" python3 "${CODEX_PLUGIN_ROOT}/hooks/session_journal_hook.py" hook --agent "Codex" <<'JSON' >/tmp/session-journal-codex-tool.json
{
  "session_id": "codex-self-test",
  "hook_event_name": "PostToolUse",
  "cwd": "/tmp/gprecious-marketplace",
  "tool_name": "Bash",
  "tool_input": { "command": "echo hi # pattern: this verbatim line must NOT become a note" }
}
JSON

env PLUGIN_ROOT="${CODEX_PLUGIN_ROOT}" python3 "${CODEX_PLUGIN_ROOT}/hooks/session_journal_hook.py" hook --agent "Codex" <<'JSON' >/tmp/session-journal-codex-stop.json
{
  "session_id": "codex-self-test",
  "hook_event_name": "Stop",
  "cwd": "/tmp/gprecious-marketplace",
  "turn_id": "turn-1",
  "stop_hook_active": false,
  "last_assistant_message": "Finished synthetic Codex work. resolved: this whole line must NOT become a durable note."
}
JSON

env CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}" python3 "${CLAUDE_PLUGIN_ROOT}/hooks/session_journal_hook.py" hook --agent "Claude Code" <<'JSON' >/tmp/session-journal-claude-prompt.json
{
  "session_id": "claude-self-test",
  "hook_event_name": "UserPromptSubmit",
  "cwd": "/tmp/gprecious-marketplace",
  "prompt": "Record this Claude prompt. Raw events are append-only and summaries are regenerated."
}
JSON

env CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}" python3 "${CLAUDE_PLUGIN_ROOT}/hooks/session_journal_hook.py" hook --agent "Claude Code" <<'JSON' >/tmp/session-journal-claude-stop.json
{
  "session_id": "claude-self-test",
  "hook_event_name": "Stop",
  "cwd": "/tmp/gprecious-marketplace",
  "stop_hook_active": false,
  "last_assistant_message": "Finished synthetic Claude work. The note carries a summary block only."
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

# Session note carries the regenerated summary block with wikilinks for the graph.
grep -q "Current Summary" "${CODEX_SESSION}"
grep -q '\[\[research-engine\]\]' "${CODEX_SESSION}"
grep -q '\[\[dream\]\]' "${CODEX_SESSION}"
grep -q '\[\[evolve\]\]' "${CODEX_SESSION}"
grep -q "Current Summary" "${CLAUDE_SESSION}"
grep -q '\[\[Claude Code\]\]' "${CLAUDE_SESSION}"
grep -q '\[\[Codex\]\]' "${CLAUDE_SESSION}"

# Summary-only contract: NO verbatim per-event transcript sections appended.
if grep -qE '^## (User Prompt|Agent Result|Tool Result|Session Start|Wiki Notes) -' "${CODEX_SESSION}"; then
  echo "FAIL: verbatim transcript section leaked into session note" >&2
  exit 1
fi
# The verbatim tool command must not be copied into the note (only the tool
# NAME appears in the summary's tool-activity line, never the command body).
if grep -q 'this verbatim line must NOT' "${CODEX_SESSION}"; then
  echo "FAIL: verbatim tool command copied into session note" >&2
  exit 1
fi
# A one-line digest of the last assistant message in the summary block IS
# expected (that is the summary); what must NOT happen is a separate
# marker-extracted durable note — covered by the no-Wiki check below.

# No auto-wiki: the Wiki/ folder must not exist and no marker note may be created.
if [ -d "${VAULT}/Wiki" ]; then
  echo "FAIL: auto-generated Wiki/ folder created" >&2
  exit 1
fi

# Raw keeps the full append-only trail (source of truth).
test "$(wc -l < "${CODEX_RAW}" | tr -d ' ')" -ge 4
test "$(wc -l < "${CLAUDE_RAW}" | tr -d ' ')" -ge 2

python3 "${ROOT}/shared/session-journal/session_journal_core.py" summarize --vault "${VAULT}" --session-id codex-self-test >/tmp/session-journal-summary.json
grep -q "session_note" /tmp/session-journal-summary.json

echo "session-journal self-test passed: ${VAULT}"

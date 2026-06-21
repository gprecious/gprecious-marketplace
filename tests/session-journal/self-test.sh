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

# --- package completeness guard: fail on stub-only plugin cache regressions ---
test -f "${CODEX_PLUGIN_ROOT}/.codex-plugin/plugin.json"
test -f "${CODEX_PLUGIN_ROOT}/hooks/hooks.json"
test -f "${CODEX_HOOK}"
test -f "${CODEX_PLUGIN_ROOT}/skills/session-journal/SKILL.md"
test -f "${CODEX_PLUGIN_ROOT}/skills/session-journal-wiki-drafts/SKILL.md"
test -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
test -f "${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json"
test -f "${CLAUDE_HOOK}"
test -f "${CLAUDE_PLUGIN_ROOT}/skills/session-journal/SKILL.md"
test -f "${CLAUDE_PLUGIN_ROOT}/skills/session-journal-wiki-drafts/SKILL.md"
test "$(wc -c < "${CODEX_HOOK}" | tr -d ' ')" -gt 1000
test "$(wc -c < "${CLAUDE_HOOK}" | tr -d ' ')" -gt 1000
grep -q '\${PLUGIN_ROOT}/hooks/session_journal_hook.py' "${CODEX_PLUGIN_ROOT}/hooks/hooks.json"
grep -q '\${CLAUDE_PLUGIN_ROOT}/hooks/session_journal_hook.py' "${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json"

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
{ "session_id": "codex-self-test", "hook_event_name": "Stop", "cwd": "${WORK}", "turn_id": "t1", "stop_hook_active": false, "last_assistant_message": "Done. Daily note keeps one upsert-able block per meaningful session." }
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

# 8. Wiki draft curation writes only draft lesson notes and reports them to Slack.
WIKI_VAULT="${TMP_DIR}/wiki-vault"
CANDIDATES="${TMP_DIR}/wiki-candidates.json"
SLACK_CAPTURE="${TMP_DIR}/slack-message.txt"
SLACK_CMD="${TMP_DIR}/slack-capture.sh"
cat >"${CANDIDATES}" <<JSON
{
  "session_id": "codex-self-test",
  "agent": "Codex",
  "workspace": "gprecious-marketplace",
  "candidates": [
    {
      "title": "Keep session-journal capture separate from wiki curation",
      "lesson": "Hooks should capture raw facts and readable summaries, while LLM-authored durable lessons stay in an explicit draft workflow.",
      "why": "Automatic wiki writes previously produced noisy stubs and verbatim fragments.",
      "how_to_apply": "Use session-journal Raw as source material, generate draft lessons, and promote only after review.",
      "confidence": "high",
      "links": ["session-journal", "LLM-Wiki"]
    },
    {
      "title": "Report session lesson drafts before promotion",
      "lesson": "Slack reports should aggregate newly created draft lesson candidates so review happens before live wiki changes.",
      "why": "Reviewable batches reduce vault pollution and keep the team aware of what an agent wants to remember.",
      "how_to_apply": "Send a concise Slack report listing draft paths, titles, confidence, and source session.",
      "confidence": "medium",
      "links": ["Slack", "session-journal"]
    }
  ]
}
JSON
cat >"${SLACK_CMD}" <<'SH'
#!/usr/bin/env bash
cat >"${SESSION_JOURNAL_SLACK_CAPTURE}"
SH
chmod +x "${SLACK_CMD}"
SESSION_JOURNAL_SLACK_REPORT_COMMAND="${SLACK_CMD}" \
SESSION_JOURNAL_SLACK_CAPTURE="${SLACK_CAPTURE}" \
python3 "${ROOT}/shared/session-journal/session_journal_core.py" wiki-draft \
  --wiki-vault "${WIKI_VAULT}" \
  --candidate-file "${CANDIDATES}" \
  >/tmp/session-journal-wiki-draft.json

test ! -d "${WIKI_VAULT}/concepts"
DRAFT_COUNT="$(find "${WIKI_VAULT}/_drafts/lessons" -type f -name '*.md' | wc -l | tr -d ' ')"
test "${DRAFT_COUNT}" -eq 2
grep -R -q 'Keep session-journal capture separate from wiki curation' "${WIKI_VAULT}/_drafts/lessons"
grep -R -q 'How To Apply' "${WIKI_VAULT}/_drafts/lessons"
grep -q '2 session-journal wiki draft candidate' "${SLACK_CAPTURE}"
grep -q 'Report session lesson drafts before promotion' "${SLACK_CAPTURE}"
grep -q '"slack_report"' /tmp/session-journal-wiki-draft.json

# 9. trivial-cwd classification: macOS real temp paths are trivial; "tmp" as a
#    substring of a real project dir is NOT a false positive.
python3 - "${ROOT}" <<'PY'
import sys, importlib.util
spec = importlib.util.spec_from_file_location("c", sys.argv[1] + "/shared/session-journal/session_journal_core.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
assert m.is_trivial_cwd("/private/var/folders/ab/xyz/T/scratch"), "private var folders must be trivial"
assert m.is_trivial_cwd("/var/folders/ab/xyz/T/scratch"), "var folders must be trivial"
assert m.is_trivial_cwd("/tmp/scratch"), "/tmp must be trivial"
assert m.is_trivial_cwd(None) and m.is_trivial_cwd(""), "empty cwd must be trivial"
assert not m.is_trivial_cwd("/Users/x/mytmp-proj/work"), "false positive: mytmp-proj"
assert not m.is_trivial_cwd("/Users/dev/gprecious-marketplace"), "false positive: real path"
print("trivial-cwd unit checks ok")
PY

echo "session-journal self-test passed: vault=${VAULT} state=${STATE}"

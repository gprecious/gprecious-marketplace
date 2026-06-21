---
name: session-journal-wiki-drafts
description: Use when the user asks to save durable lessons from session-journal into the LLM-Wiki, collect mistakes or insights from agent work, create reviewable wiki draft candidates, or report those draft candidates to Slack.
---

# Session Journal Wiki Drafts

Use this skill to distill reusable lessons from captured session-journal raw logs
into reviewable LLM-Wiki draft notes. This is an LLM task, so it is never run by
the hook automatically.

## Safety Model

- Write only to `LLM-Wiki/_drafts/lessons/` and `_drafts/reports/`.
- Do not write live `concepts/`, `entities/`, or `synthesis/` pages.
- Do not promote drafts unless the user explicitly asks.
- Do not copy transcripts verbatim. Save distilled lessons only.
- Skip weak candidates. It is valid to produce zero drafts.
- Never save secrets, credentials, tokens, passwords, private keys, or transient
  logs. The helper redacts obvious secret patterns, but you must still filter.
- Slack reporting is a notification about draft candidates, not approval to
  promote them.

## Candidate Criteria

Create a draft only when the lesson is reusable by future agents. Good examples:

- A concrete failure mode and how to avoid it.
- A repo convention or workflow boundary that future agents should follow.
- A tool integration discovery that prevents wasted work.
- A verification pattern that caught a real mistake.

Reject low-value chatter, status updates, one-off commands, unverified guesses,
and anything that only repeats what the user asked.

## Workflow

1. Find the raw session log under `$XDG_STATE_HOME/session-journal/Raw/` or
   `~/.local/state/session-journal/Raw/`. If needed, run:

   ```bash
   python3 "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/hooks/session_journal_hook.py" where
   ```

2. Read the raw log for the target session. Use the daily note only as an index;
   the raw log is the source of truth.
3. Distill zero or more candidates into this JSON shape:

   ```json
   {
     "session_id": "codex-self-test",
     "agent": "Codex",
     "workspace": "gprecious-marketplace",
     "candidates": [
       {
         "title": "Short reusable lesson title",
         "lesson": "The distilled lesson.",
         "why": "Why future agents should care.",
         "how_to_apply": "Concrete steps to apply it next time.",
         "confidence": "high",
         "links": ["session-journal", "LLM-Wiki"],
         "tags": ["optional-extra-tag"]
       }
     ]
   }
   ```

4. Write the JSON to a temporary file and call the helper:

   ```bash
   python3 "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/hooks/session_journal_hook.py" wiki-draft \
     --candidate-file /tmp/session-journal-wiki-candidates.json
   ```

   Optional: pass `--wiki-vault /absolute/path/to/LLM-Wiki` to pin the target.
   Otherwise the helper resolves `WIKI_VAULT`, then
   `LLM_OBSIDIAN_VAULT_NAME` + `LLM_WIKI_SUBDIR` (default `LLM-Wiki`), then
   local `./wiki`.

5. If candidates were created, the helper writes:

   ```text
   <LLM-Wiki>/_drafts/lessons/YYYY-MM-DD-<session>-<slug>.md
   <LLM-Wiki>/_drafts/reports/YYYY-MM-DD-<session>-wiki-draft-report.md
   ```

6. Report the created draft count, paths, skipped candidates, and Slack status.

## Slack Reporting

When one or more drafts are created, the helper sends one aggregated Slack report
if either environment variable is configured:

- `SESSION_JOURNAL_SLACK_WEBHOOK_URL` — Slack incoming webhook URL.
- `SESSION_JOURNAL_SLACK_REPORT_COMMAND` — command that receives the report on
  stdin. Use this for Hermes or other local Slack senders.

If neither is configured, the helper still writes `_drafts/reports/...md` and
returns `slack_report.sent=false`.

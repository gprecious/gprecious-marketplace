---
name: session-journal
description: Use when the user asks to inspect, summarize, explain, or manually run the session-journal Obsidian logging workflow for Claude Code or Codex sessions.
---

# Session Journal

Use this skill when the user asks about the session-journal vault, hook output, generated wiki notes, or wants a manual summary refresh.

## What the hooks record

The plugin writes to `LLM_OBSIDIAN_VAULT` when set, otherwise to `~/Documents/Obsidian/llm-agent-vault`.

Layout:

```text
Index.md
Sessions/YYYY-MM-DD/<session-id>.md
Raw/YYYY-MM-DD/<session-id>.jsonl
Wiki/*.md
```

`UserPromptSubmit` records the user prompt. `PostToolUse` records tool names and command snippets. `Stop` records the final assistant message and refreshes the session summary. The raw log is append-only; the readable summary block in the session note is regenerated.

## Manual summary refresh

If the hook could only capture raw events, refresh a session note with:

```bash
python3 "${PLUGIN_ROOT}/hooks/session_journal_hook.py" summarize --session-id <session-id>
```

If `PLUGIN_ROOT` is unavailable, locate the installed `session-journal` plugin root and run the same script from its `hooks/` directory.

## Wiki-worthy notes

Create durable wiki notes only for reusable information:

- implementation patterns
- repo conventions
- integration discoveries
- resolved failure modes

Do not save secrets, credentials, transient logs, or low-value one-off chatter. Durable note candidates are currently marker-based: lines containing `wiki-worthy`, `pattern:`, `convention:`, `integration:`, `failure mode:`, `resolved:`, or `lesson:`.

Generated notes include Obsidian links such as `[[Claude Code]]`, `[[Codex]]`, `[[research-engine]]`, `[[dream]]`, `[[evolve]]`, and `[[herdr]]` so the vault graph connects agent work to related concepts.

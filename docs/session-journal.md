# Session Journal Plugin

`session-journal` records Claude Code and Codex sessions into a dedicated Obsidian vault for LLM and agent work.

## Install and Use

Install the plugin from this marketplace:

- Claude Code: `claude-plugins/session-journal`
- Codex: `.agents/plugins/plugins/session-journal`

Enable or trust the plugin hooks in the host tool's hook UI. Both Claude Code and Codex require hook review/trust for non-managed plugin hooks before commands run.

Set an explicit vault path when desired:

```bash
export LLM_OBSIDIAN_VAULT="$HOME/Documents/Obsidian/llm-agent-vault"
```

If unset, the plugin writes to `~/Documents/Obsidian/llm-agent-vault`.

For Claude Code, the most reliable way to set this is the `env` block in
`~/.claude/settings.json` (hooks inherit it on session start). For Codex, export
it from your shell profile or Codex config so the shared core sees the same path.

### Merging into an existing (e.g. Obsidian Sync) vault

To keep agent logs inside a vault you already use, point `LLM_OBSIDIAN_VAULT` at a
dedicated **subfolder** of that vault rather than its root:

```bash
export LLM_OBSIDIAN_VAULT="$HOME/Documents/obsidian/<your-vault>/AI-Journal"
```

The plugin then writes `Index.md`, `Sessions/`, `Raw/`, and `Wiki/` under that
subfolder only — never mixed at the vault root. Combined with the `#ai-generated`
tag (below), this keeps AI-authored content cleanly separated from your own notes
at both the file-tree and search/graph level, and lets Obsidian Sync's selective
sync include or exclude the branch as a unit.

## Vault Layout

```text
Index.md
Sessions/YYYY-MM-DD/<session-id>.md
Raw/YYYY-MM-DD/<session-id>.jsonl
Wiki/*.md
```

- `Raw/` is append-only JSONL from lifecycle hooks.
- `Sessions/` is human-readable markdown with prompts, tool activity, final agent result, and a regenerated summary block.
- `Wiki/` stores durable notes and keyword notes that make Obsidian graph links visible.

## AI-Generated Tagging

Every note the plugin writes — `Index.md`, session notes, keyword notes, and
durable wiki notes — carries this YAML frontmatter so it is unambiguously
distinct from hand-authored notes when the vault is shared:

```yaml
tags:
  - ai-generated
  - session-journal
```

`Index.md` additionally opens with a `> [!info] 🤖 AI-generated` callout. In
Obsidian you can filter or exclude all plugin output with `tag:#ai-generated`
in search, color it in graph view, or query it with Dataview. The tag set lives
in `AI_TAGS` in the shared core.

## Hook Behavior

The plugin registers:

- `SessionStart` to create the vault and session note.
- `UserPromptSubmit` to capture the user's prompt close to real time.
- `PostToolUse` to capture tool names and command snippets.
- `Stop` to capture the final assistant message and refresh the summary.

The shared core is `shared/session-journal/session_journal_core.py`. Claude and Codex plugin wrappers call this same core from their own hook entrypoints. Each wrapper resolves the core by walking up from its plugin root / cwd and, as a fallback, by locating the full marketplace checkout under the host tool's plugin install roots — so resolution never depends on the hook's working directory (cached plugin copies do not bundle `shared/`). Override with `SESSION_JOURNAL_CORE` if needed.

## Known Limitations

- Hook commands do not call an LLM directly. They create deterministic summaries from prompts, tool names, and final assistant messages.
- Full transcript parsing is intentionally avoided because Codex documents transcript format as unstable and Claude also exposes the fields needed for this workflow directly through hook inputs.
- Raw prompt logging can contain user-provided sensitive text. The core redacts obvious token, password, secret, credential, and API-key patterns, but users should avoid pasting secrets into agent prompts.

## Wiki-Worthy Notes

The hook writes durable wiki notes when a prompt or assistant result contains marker-style lines such as:

- `wiki-worthy: ...`
- `pattern: ...`
- `convention: ...`
- `integration: ...`
- `failure mode: ...`
- `resolved: ...`
- `lesson: ...`

This conservative rule is intentional. The wiki should capture reusable implementation patterns, repo conventions, integration discoveries, and resolved failure modes, not transient logs.

## Obsidian Links

Generated notes include links such as:

- `[[Claude Code]]`
- `[[Codex]]`
- `[[research-engine]]`
- `[[dream]]`
- `[[evolve]]`
- `[[herdr]]`
- `[[session-journal]]`
- the current repo name, such as `[[gprecious-marketplace]]`

The plugin also creates keyword notes under `Wiki/` so the graph can connect session notes, durable notes, and related concepts.

## research-engine, dream, and evolve Integration

`research-engine` persists each `/research` run under `research/YYYY-MM-DD-<slug>/` with `README.md`, `sources.json`, and `intent.json`, then optionally mirrors the report to Notion.

Its cross-session learning layer uses:

- `/dream` to extract repeated patterns into `docs/dreams/<run-id>/insights/pattern-*.md`.
- `/evolve` to use dream and bench signals to mutate marked evolvable adapter regions, compare current vs candidate behavior, and update `research/_index/evolve-ledger.json`.

`session-journal` follows the same durable-local-artifact idea at session granularity:

- raw hook events are the audit trail
- session markdown is the readable report
- wiki notes are the durable insight layer
- Obsidian wikilinks make related concepts inspectable through the graph

It does not auto-trigger `/dream` or `/evolve`; it links to those concepts and records integration discoveries so later research-engine work can reuse them.

## Manual Summary

Refresh a session summary after raw capture:

```bash
python3 <plugin-root>/hooks/session_journal_hook.py summarize --session-id <session-id>
```

## Self-Test

Run the synthetic temp-vault test from the marketplace root:

```bash
bash tests/session-journal/self-test.sh
```

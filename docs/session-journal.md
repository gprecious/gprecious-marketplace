# Session Journal Plugin

`session-journal` records Claude Code and Codex sessions into a dedicated Obsidian vault for LLM and agent work.

## Install and Use

Install the plugin from this marketplace:

- Claude Code: `claude-plugins/session-journal`
- Codex: `.agents/plugins/plugins/session-journal`

Enable or trust the plugin hooks in the host tool's hook UI. Both Claude Code and Codex require hook review/trust for non-managed plugin hooks before commands run.

### Choosing the vault

The core resolves the vault in this precedence order:

1. **`LLM_OBSIDIAN_VAULT`** — an explicit absolute path. Use for a per-machine
   override.

   ```bash
   export LLM_OBSIDIAN_VAULT="$HOME/Documents/Obsidian/llm-agent-vault"
   ```

2. **`LLM_OBSIDIAN_VAULT_NAME`** (+ optional **`LLM_OBSIDIAN_SUBDIR`**) — resolve
   an Obsidian vault by **name** and descend into a subfolder. The core reads the
   Obsidian desktop app's `obsidian.json` (macOS/Linux/Windows) to find the
   named vault's local path, preferring an open then most-recently-used match.

   ```bash
   export LLM_OBSIDIAN_VAULT_NAME="harry"
   export LLM_OBSIDIAN_SUBDIR="AI-Journal"
   ```

3. **Default** — `~/Documents/Obsidian/llm-agent-vault` when nothing is set, or
   when a named vault can't be resolved on this machine.

For Claude Code, set these in the `env` block of `~/.claude/settings.json` (hooks
inherit it on session start). For Codex, export them from `~/.zshenv` (or your
shell profile / Codex config) so the shared core sees them too.

### Merging into an existing vault (subfolder)

To keep agent logs inside a vault you already use, target a dedicated
**subfolder** rather than the vault root — via `LLM_OBSIDIAN_SUBDIR` (name mode)
or by pointing `LLM_OBSIDIAN_VAULT` at `.../<your-vault>/AI-Journal`. The plugin
then writes `Index.md`, `Sessions/`, `Raw/`, and `Wiki/` under that subfolder
only — never mixed at the vault root. Combined with the `#ai-generated` tag
(below), AI-authored content stays cleanly separated from your own notes at both
the file-tree and search/graph level.

### Multi-machine access via Obsidian Sync

Because the journal lives in a **subfolder of a real vault**, it rides that
vault's existing sync. With Obsidian Sync (the paid service) on the vault:

- **Content propagates automatically** — every machine and the mobile app that
  syncs the vault receives the `AI-Journal/` notes. No extra wiring.
- **Use name-based config** (mode 2 above) so the *same* env works on every
  machine: the absolute path differs per machine, but the vault name is stable
  and each machine resolves it through its own `obsidian.json`.
- **Selective sync**: in Obsidian Sync settings, ensure `AI-Journal/` is not
  excluded. Note that Obsidian Sync only carries `.jsonl` raw logs when *"Sync
  all other file types"* is enabled — leave it off to sync just the readable
  `.md` notes and keep the bulky append-only `Raw/` logs machine-local.
- **Conflicts are rare**: each session writes its own uniquely-named files, so
  concurrent sessions on different machines don't contend; `Index.md` is only
  written when missing.

The plugin's hooks only run where an agent (Claude Code / Codex) runs — other
machines and mobile are read-only consumers of the synced notes.

#### Setting up a new machine

1. **Sync the vault**: install Obsidian, sign in to the same Obsidian Sync
   account, and connect the vault (e.g. `harry`). Obsidian downloads it locally
   and registers it in that machine's `obsidian.json` — which is what name-based
   resolution reads. Ensure `AI-Journal/` is included in selective sync.
2. **Install the plugin** from this marketplace (Claude Code and/or Codex) and
   trust its hooks.
3. **Configure the vault** — the *same* lines on every machine:
   - Claude Code → `~/.claude/settings.json`:
     ```json
     "env": { "LLM_OBSIDIAN_VAULT_NAME": "harry", "LLM_OBSIDIAN_SUBDIR": "AI-Journal" }
     ```
   - Codex / shell → `~/.zshenv`:
     ```bash
     export LLM_OBSIDIAN_VAULT_NAME="harry"
     export LLM_OBSIDIAN_SUBDIR="AI-Journal"
     ```
4. **Restart** Claude Code / open a new shell so the env loads, then verify (below).

If the machine has no Obsidian app (e.g. a headless server), name resolution
can't read `obsidian.json` and falls back to the default vault — set an explicit
`LLM_OBSIDIAN_VAULT` absolute path there instead.

#### Updating an already-installed machine

1. Update the marketplace + plugin to the current version (via `/plugin`, or
   `claude plugin marketplace update gprecious-marketplace` then reinstall).
   This also clears the older "Duplicate hooks file detected" load error.
2. Add the two env vars (step 3 above) if not already present.
3. Restart Claude Code / reopen the shell, then verify.

#### Verifying the configuration

Run the `where` subcommand on any machine to confirm the resolved vault:

```bash
python3 <plugin-root>/hooks/session_journal_hook.py where
```

It prints the resolved vault path, the resolution mode (`explicit` / `name` /
`default`), the env it saw, and `ok: true/false`. `ok: false` with
`"named vault NOT found"` means Obsidian hasn't registered that vault on this
machine yet — open it in Obsidian once. Precedence: an explicit
`LLM_OBSIDIAN_VAULT` overrides the name vars, so set only the name vars for a
portable config.

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

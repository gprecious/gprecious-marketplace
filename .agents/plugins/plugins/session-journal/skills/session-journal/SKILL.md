---
name: session-journal
description: Use when the user asks to inspect, summarize, explain, configure, connect, or troubleshoot the session-journal Obsidian logging workflow for Claude Code or Codex — including pointing it at an existing/Obsidian-Sync vault, keeping AI-generated notes distinct from hand-authored ones, multi-machine setup, or verifying the vault config.
---

# Session Journal

Use this skill for anything about the session-journal vault: inspecting output,
choosing where it writes, connecting it to an existing (Obsidian Sync) vault while
keeping AI notes distinct, multi-machine setup, manual summary refresh, and
troubleshooting. Full reference: `docs/session-journal.md` in the marketplace.

## What the hooks record

`SessionStart` creates the vault/note, `UserPromptSubmit` records the prompt,
`PostToolUse` records tool names + command snippets, `Stop` records the final
assistant message and regenerates the summary block. Raw JSONL is append-only;
the readable summary block is regenerated. Layout:

```text
Index.md
Sessions/YYYY-MM-DD/<session-id>.md
Raw/YYYY-MM-DD/<session-id>.jsonl
Wiki/*.md
```

## Configuring the vault (resolution precedence)

The shared core resolves the vault in this order:

1. **`LLM_OBSIDIAN_VAULT`** — explicit absolute path (per-machine override).
2. **`LLM_OBSIDIAN_VAULT_NAME`** (+ optional **`LLM_OBSIDIAN_SUBDIR`**) — resolve an
   Obsidian vault by **name** via the OS `obsidian.json`, then descend into a
   subfolder. Portable: the same env works on every machine.
3. **Default** — `~/Documents/Obsidian/llm-agent-vault`.

Set these for Codex in `~/.zshenv` (or your shell profile / Codex config); for
Claude Code in the `env` block of `~/.claude/settings.json`. The shared core reads
the same vars either way.

### Connecting to an existing vault, AI notes kept distinct

Target a dedicated **subfolder** of the vault, never its root — e.g.
`LLM_OBSIDIAN_SUBDIR=AI-Journal`. Every generated note (Index, session, keyword,
durable) is stamped with frontmatter `tags: [ai-generated, session-journal]` and
the Index opens with a `🤖 AI-generated` callout. The user filters or excludes all
plugin output with `tag:#ai-generated` in search/graph. Subfolder + tag gives
file-tree, search, and graph separation from hand-authored notes.

## Multi-machine via Obsidian Sync

The journal lives in a subfolder of a real vault, so Obsidian Sync carries it to
every machine and mobile automatically — no extra wiring. Use **name-based config**
(mode 2) so the *same* env works everywhere; each machine resolves its own local
path through `obsidian.json`.

- **New machine**: (1) connect the vault via Obsidian Sync so Obsidian registers
  it locally, (2) install the plugin + trust hooks, (3) set the two name env vars,
  (4) restart and verify.
- **Already-installed machine**: update the plugin, add the two env vars, restart,
  verify.
- **Headless (no Obsidian app)**: name resolution can't read `obsidian.json` and
  falls back to default — set an explicit `LLM_OBSIDIAN_VAULT` there instead.
- **Selective sync**: keep `AI-Journal/` included; `.jsonl` raw logs only sync if
  "Sync all other file types" is on — leave it off to sync just readable `.md`.

## Verifying setup

Confirm the resolved vault on any machine:

```bash
python3 "${PLUGIN_ROOT}/hooks/session_journal_hook.py" where
```

Prints `resolved_vault`, `resolution_mode` (explicit/name/default), the env seen,
and `ok`. `ok: false` with `"named vault NOT found"` means Obsidian hasn't
registered that vault on this machine — open it in Obsidian once. An explicit
`LLM_OBSIDIAN_VAULT` overrides the name vars, so set only the name vars for a
portable config.

## Manual summary refresh

```bash
python3 "${PLUGIN_ROOT}/hooks/session_journal_hook.py" summarize --session-id <session-id>
```

If `PLUGIN_ROOT` is unavailable, run the same script from the installed plugin's
`hooks/` directory (or the marketplace clone's
`shared/session-journal/session_journal_core.py`).

## Wiki-worthy notes

Durable notes are written only for reusable info — implementation patterns, repo
conventions, integration discoveries, resolved failure modes. Marker-based: lines
containing `wiki-worthy`, `pattern:`, `convention:`, `integration:`,
`failure mode:`, `resolved:`, or `lesson:`. Never save secrets/credentials (the
core also redacts obvious token/key/password patterns), transient logs, or
low-value chatter. Generated notes link `[[Claude Code]]`, `[[Codex]]`,
`[[research-engine]]`, `[[dream]]`, `[[evolve]]`, `[[herdr]]` for graph navigation.

## Troubleshooting

- **`session-journal core not found`** — cached plugin copies don't bundle
  `shared/`; fixed in ≥0.2.0 with cwd-independent resolution. Update the plugin.
- **`Duplicate hooks file detected` on load** — fixed in ≥0.3.0 (hooks.json is
  auto-discovered; the manifest no longer re-declares it). Update the plugin.
- **Notes go to the wrong/default vault** — run `where`; if `ok: false`, the named
  vault isn't registered in Obsidian on that machine, or an explicit
  `LLM_OBSIDIAN_VAULT` is shadowing the name vars.

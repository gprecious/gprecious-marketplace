---
name: session-journal
description: Use when the user asks to inspect, summarize, explain, configure, connect, curate, or troubleshoot the session-journal Obsidian logging workflow for Claude Code or Codex — including pointing it at an existing/Obsidian-Sync vault, keeping AI-generated notes distinct from hand-authored ones, multi-machine setup, distilling durable knowledge, or verifying the vault config.
---

# Session Journal

Use this skill for anything about the session-journal vault: inspecting output,
choosing where it writes, connecting it to an existing (Obsidian Sync) vault while
keeping AI notes distinct, multi-machine setup, manual summary refresh, curating
durable knowledge, and troubleshooting. Full reference: `docs/session-journal.md`
in the marketplace.

## What the hooks record (capture-only)

The hook is **pure Python — no LLM**, so it only captures; it never auto-authors
"knowledge". It produces two things, and only **meaningful** sessions reach the
readable note (throwaway sessions — a tmp working dir, or no real prompt/result —
are skipped, so not every session is listed):

- **`Journal/YYYY-MM-DD.md`** (in the vault) — one daily note holding a
  chronological, **upsert-able summary block per session** (start time, workspace,
  agent, recent prompt + result first-lines, tool names). `UserPromptSubmit` /
  `Stop` create or refresh that session's block in place — re-running never
  duplicates it; `SessionStart` / `PostToolUse` only touch the raw log.
- **`Raw/YYYY-MM-DD/<id>.jsonl`** (OUTSIDE the vault, under
  `$XDG_STATE_HOME/session-journal/`) — append-only full event log, the source of
  truth the daily block is built from. Pruned past
  `SESSION_JOURNAL_RAW_RETENTION_DAYS` (default 30), so the bulky trail never
  enters the vault and Obsidian Sync only carries the readable `.md`.

```text
<vault>/Index.md
<vault>/Journal/YYYY-MM-DD.md                              # readable daily journal (synced)
$XDG_STATE_HOME/session-journal/Raw/YYYY-MM-DD/<id>.jsonl  # raw log, machine-local
```

There is **no auto-generated `Wiki/`** folder and no marker-based note extraction.
That heuristic produced link-only stubs and verbatim conversational fragments, so
it was removed. Durable knowledge is curated on demand (see below).

## Configuring the vault (resolution precedence)

The shared core resolves the vault in this order:

1. **`LLM_OBSIDIAN_VAULT`** — explicit absolute path (per-machine override).
2. **`LLM_OBSIDIAN_VAULT_NAME`** (+ optional **`LLM_OBSIDIAN_SUBDIR`**) — resolve an
   Obsidian vault by **name** via the OS `obsidian.json`, then descend into a
   subfolder. Portable: the same env works on every machine.
3. **Default** — `~/Documents/Obsidian/llm-agent-vault`.

For Codex, export these from `~/.zshenv` (or your shell profile / Codex config) so
the shared core sees them. (Claude Code uses the `env` block of
`~/.claude/settings.json`.)

> **Pin explicit when a name is ambiguous.** If a machine has **more than one**
> vault with the same folder name (e.g. a live local copy plus a stale iCloud
> copy), name resolution flips between them depending on which was last open —
> splitting writes across both ("split-brain"). `where` reports
> `named_vault_candidates` and warns when this happens. Fix it by pinning
> `LLM_OBSIDIAN_VAULT` to the absolute path of the live vault's subfolder, e.g.
> `~/Documents/obsidian/harry/AI-Journal`.

### Connecting to an existing vault, AI notes kept distinct

Target a dedicated **subfolder** of the vault, never its root — e.g.
`LLM_OBSIDIAN_SUBDIR=AI-Journal`. Every generated note (Index, daily journal note)
is stamped with frontmatter `tags: [ai-generated, session-journal]` and the Index opens with
a `🤖 AI-generated` callout. Filter or exclude all plugin output with
`tag:#ai-generated` in search/graph. Subfolder + tag gives file-tree, search, and
graph separation from hand-authored notes.

## Multi-machine via Obsidian Sync

The journal lives in a subfolder of a real vault, so Obsidian Sync carries it to
every machine and mobile automatically — no extra wiring. Use **name-based config**
(mode 2) so the *same* env works everywhere; each machine resolves its own local
path through `obsidian.json` — *unless* that machine has a duplicate same-named
vault, in which case pin `LLM_OBSIDIAN_VAULT` explicitly there.

- **New machine**: (1) connect the vault via Obsidian Sync so Obsidian registers
  it locally, (2) install the plugin + trust hooks, (3) set the name env vars,
  (4) restart and verify.
- **Already-installed machine**: update the plugin, add the env vars, restart, verify.
- **Headless (no Obsidian app)**: name resolution can't read `obsidian.json` and
  falls back to default — set an explicit `LLM_OBSIDIAN_VAULT` there instead.
- **Selective sync**: keep `AI-Journal/` included. Raw `.jsonl` logs now live
  **outside the vault** (`$XDG_STATE_HOME/session-journal/`), so there's nothing
  bulky to exclude — Obsidian Sync only carries the readable daily notes.

## Verifying setup

```bash
python3 "${PLUGIN_ROOT}/hooks/session_journal_hook.py" where
```

Prints `resolved_vault`, `resolution_mode` (explicit/name/default), the env seen,
`named_vault_candidates`, any `warnings`, and `ok`. `ok: false` with
`"named vault NOT found"` means Obsidian hasn't registered that vault on this
machine — open it in Obsidian once. A non-empty `warnings` list means a duplicate
same-named vault was found — pin `LLM_OBSIDIAN_VAULT`.

## Manual summary refresh

```bash
python3 "${PLUGIN_ROOT}/hooks/session_journal_hook.py" summarize --session-id <session-id>
```

If `PLUGIN_ROOT` is unavailable, run the same script from the installed plugin's
`hooks/` directory (or the marketplace clone's
`shared/session-journal/session_journal_core.py`).

## Curating durable knowledge (on demand)

Distilling reusable lessons is an LLM task — done **on request**, never by the
hook. When the user asks to "save what we learned" / "make a wiki note":

- Write a **distilled summary** (the lesson, the key decision, the reusable
  pattern), not a verbatim copy of the conversation. Capture *why* it matters and
  *how to apply it later*.
- Prefer the proper curated wiki: **research-engine `/wiki`** (the LLM-authored
  Obsidian wiki under `LLM-Wiki/`), or the user's own notes. Read the source
  session from `Raw/` if you need the details.
- Never save secrets/credentials (the core also redacts obvious token/key/password
  patterns), transient logs, or low-value chatter.
- Avoid creating link-only stub notes — a note must carry real distilled content.

## Troubleshooting

- **`session-journal core not found`** — cached plugin copies don't bundle
  `shared/`; fixed in ≥0.2.0 with cwd-independent resolution. Update the plugin.
- **`Duplicate hooks file detected` on load** — fixed in ≥0.3.0. Update the plugin.
- **Notes split across two vaults / go to the wrong vault** — a duplicate
  same-named vault is on this machine. Run `where`; if `warnings` is non-empty or
  `resolution_mode` is `name`, pin `LLM_OBSIDIAN_VAULT` to the live vault's
  absolute subfolder path.
- **One note per session / a `Sessions/` folder / in-vault `Raw/`** — pre-0.6.0
  behavior. Update the plugin; sessions now roll up into one `Journal/<date>.md`
  daily note (meaningful sessions only) and the raw log moved outside the vault.
- **Session notes huge or `Wiki/` full of stubs** — pre-0.5.0 behavior; verbatim
  transcripts and auto-wiki were already removed.

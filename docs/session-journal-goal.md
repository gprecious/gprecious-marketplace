# Session Journal Goal

Build a local `gprecious-marketplace` plugin, likely `session-journal` or `obsidian-journal`, that works in both Claude Code and Codex.

## Goal

Capture the user's prompts and agent work results during a session, summarize them, and store them in a dedicated Obsidian vault for LLM and agent work. Record activity close to real time where hooks allow it. Save durable, wiki-worthy information when the agent judges it useful.

## Required Research First

Use herdr throughout the work. Confirm `HERDR_ENV=1`, inspect the current panes and tabs, and use herdr for research, implementation, or verification coordination where useful.

Before coding, research current Claude Code and Codex support for:

- hooks
- skills
- plugin manifests
- session and event inputs
- limitations around capturing prompts and model outputs

Also inspect the existing `research-engine` implementation, especially:

- wiki or memory persistence behavior
- `/research`
- `/dream`
- `/evolve`
- how dream and evolve produce durable insights
- how marketplace manifests expose plugins for Claude Code and Codex

## Implementation Requirements

Create a shared core used by both Claude Code and Codex wrappers.

The plugin must support:

- a dedicated Obsidian vault for LLM work
- default vault path via `LLM_OBSIDIAN_VAULT`
- fallback default `~/Documents/Obsidian/llm-agent-vault`
- append-only raw session event logs
- readable per-session markdown summaries
- wiki notes for durable knowledge
- Obsidian wikilinks for related concepts
- links for keywords such as `[[Claude Code]]`, `[[Codex]]`, `[[research-engine]]`, `[[dream]]`, `[[evolve]]`, `[[herdr]]`, repo names, plugin names, and task keywords

If hook APIs cannot summarize with an LLM in real time, capture raw events in real time and provide a skill or command that summarizes them afterward.

Use conservative wiki-worthiness rules:

- save reusable implementation patterns
- save repo conventions
- save integration discoveries
- save resolved failure modes
- do not save transient noise, secrets, credentials, or low-value logs

## Marketplace Requirements

Add compatible local plugin entries for both ecosystems:

- Claude Code plugin under `claude-plugins/<name>/`
- Codex plugin under `.agents/plugins/plugins/<name>/`
- update `.claude-plugin/marketplace.json`
- update `.agents/plugins/marketplace.json`

Respect existing manifest conventions in this repo.

## Documentation

Document:

- install and use flow
- environment variables
- vault layout
- hook behavior
- known limitations
- how this connects to `research-engine`, `dream`, and `evolve`
- how Obsidian graph links are created

## Verification

Add a temp-vault self-test using synthetic Claude and Codex-like events.

Done when:

- synthetic events create raw session logs
- synthetic events create a readable session summary
- wiki-worthy synthetic content creates wiki notes
- generated notes contain Obsidian wikilinks
- manifests validate with `jq`
- existing tests pass where available
- `git status` is reviewed
- if repo rules require it, commit and push after verification

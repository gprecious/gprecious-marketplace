# session-journal 0.8.0 release note

## Incident

The local Codex cache contained an incomplete `session-journal/0.7.0` install:

- `~/.codex/plugins/cache/gprecious-marketplace/session-journal/0.7.0/hooks/session_journal_hook.py` was a 194 byte no-op placeholder.
- `.codex-plugin/plugin.json`, `hooks/hooks.json`, `README.md`, and `skills/` were absent.
- The previous `0.6.0` cache was complete and its hook wrapper matched the repository copy.

When Codex tried to run a configured lifecycle hook against a missing or stubbed
`0.7.0` path, `UserPromptSubmit`/`SessionStart` failed before the user command
could run.

## Root Cause

`0.7.0` was never a clean committed dual-tree release. The dirty worktree had
version/description changes and a new wiki-draft skill, but the installed cache
directory was manually hotfixed with only a placeholder hook to unblock command
execution. Because the repo had no package-completeness gate for
`session-journal`, that stub-only cache could coexist with a marketplace entry
advertising `0.7.0`.

The repository source of truth was not missing the hook layout: both trees use
the expected files:

- Codex: `.agents/plugins/plugins/session-journal/.codex-plugin/plugin.json`,
  `hooks/hooks.json`, `hooks/session_journal_hook.py`, `skills/`.
- Claude: `claude-plugins/session-journal/.claude-plugin/plugin.json`,
  `hooks/hooks.json`, `hooks/session_journal_hook.py`, `skills/`.

The defect was the release/install boundary: version bump and cache repair were
not backed by a committed, dual-tree-verified package.

## 0.8.0 Fix

- Bump both plugin manifests to `0.8.0`.
- Keep Codex and Claude hook wrappers, hook manifests, README, and skills aligned.
- Add `session-journal-wiki-drafts` as an explicit human-triggered skill; hooks
  remain capture-only and do not write live wiki pages.
- Extend `tests/session-journal/self-test.sh` with a package completeness guard
  that fails if either tree lacks plugin manifests, hooks, required skills, or if
  the hook wrapper is a tiny placeholder.

Release gate:

```bash
bash tests/session-journal/self-test.sh
python3 scripts/dual-tree-check.py
```

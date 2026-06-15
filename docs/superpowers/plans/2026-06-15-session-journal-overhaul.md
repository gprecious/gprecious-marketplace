# Session-Journal Overhaul Implementation Plan (Plan A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace per-session Obsidian notes with a single chronological daily journal note that records only *meaningful* sessions, move the bulky raw JSONL log out of the vault (with retention), and keep multi-machine name-based vault resolution — verified by the rewritten `self-test.sh` and the dual-tree gate.

**Architecture:** `shared/session-journal/session_journal_core.py` is the single source of truth; Claude/Codex trees are thin `find_core` wrappers that need no logic change. The journal becomes `Journal/<date>.md` with one upsert-able block per session (keyed by `session:<id>` HTML comment markers, first-seen = chronological order). Raw events move to `$XDG_STATE_HOME/session-journal/Raw/<date>/<id>.jsonl` (outside any vault), pruned past a retention window. A "meaningful session" gate drops throwaway sessions (tmp cwd, no real prompt/result) so not every session is listed.

**Tech Stack:** Python 3 stdlib only (no new deps). Bash integration test. JSON plugin manifests.

**Out of scope for this plan:** research-engine auto-wiki (Plan B, external repo), deletion of existing accumulated vault data (separate confirmed cleanup step), `~/.claude/settings.json` env switch (separate machine-config step).

---

## File Structure

- Modify: `shared/session-journal/session_journal_core.py` — all behavior changes live here.
- Rewrite: `tests/session-journal/self-test.sh` — new contract (daily note, external raw, trivial-skip).
- Modify: `docs/session-journal.md` — document new layout + raw location + retention.
- Modify: `claude-plugins/session-journal/skills/session-journal/SKILL.md` + `.agents/plugins/plugins/session-journal/skills/session-journal/SKILL.md` — keep semantics in sync (preserve any platform-specific blocks).
- Modify: `claude-plugins/session-journal/README.md` + `.agents/plugins/plugins/session-journal/README.md` — layout note.
- Bump: `claude-plugins/session-journal/.claude-plugin/plugin.json` + `.agents/plugins/plugins/session-journal/.codex-plugin/plugin.json` — `0.5.0 → 0.6.0` (behavior change, both together).
- Wrappers (`hooks/session_journal_hook.py` both trees): **no change** (they only locate+load the core).

## New core contract (locked decisions)

- **Daily note:** `vault/Journal/<YYYY-MM-DD>.md`. One block per session between
  `<!-- session:<id>:start -->` / `<!-- session:<id>:end -->`. Upsert in place on
  `UserPromptSubmit`/`Stop`; first-seen append = chronological. **No** `Sessions/<id>.md` files.
- **Raw:** `state_root()/Raw/<date>/<id>.jsonl` where `state_root()` =
  `$SESSION_JOURNAL_STATE` → `$XDG_STATE_HOME/session-journal` → `~/.local/state/session-journal`.
  Never written inside the vault.
- **Retention:** on `SessionStart`, delete `Raw/<date>/` dirs older than
  `$SESSION_JOURNAL_RAW_RETENTION_DAYS` (default 30).
- **Meaningful gate:** a session gets a block only when cwd is not a throwaway tmp
  path AND it has ≥1 non-empty user prompt AND (≥1 tool use OR ≥1 non-empty result).
- **Vault resolution:** unchanged (`explicit` → `name` → default), still the
  multi-machine portable path.

---

### Task 1: Rewrite the integration test for the new contract (RED)

**Files:**
- Rewrite: `tests/session-journal/self-test.sh`

- [ ] **Step 1: Replace `self-test.sh` with the new contract test**

```bash
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

emit() { python3 "$1" hook --agent "$2"; }  # reads JSON on stdin

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
{ "session_id": "codex-self-test", "hook_event_name": "Stop", "cwd": "${WORK}", "turn_id": "t1", "stop_hook_active": false, "last_assistant_message": "Done. resolved: this whole line must NOT become a durable note." }
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

echo "session-journal self-test passed: vault=${VAULT} state=${STATE}"
```

- [ ] **Step 2: Run it to confirm it fails against the current core**

Run: `bash tests/session-journal/self-test.sh`
Expected: FAIL (current core writes `Sessions/` + in-vault `Raw/`, no `Journal/`).

---

### Task 2: Move raw logs out of the vault + add `state_root()` and retention

**Files:**
- Modify: `shared/session-journal/session_journal_core.py`

- [ ] **Step 1: Add imports + state/retention helpers** (after the `expand` function, ~line 64)

```python
import shutil  # add to the import block at top

DAILY_DIR = "Journal"
DEFAULT_RAW_RETENTION_DAYS = 30


def state_root() -> pathlib.Path:
    """Where raw JSONL logs live — OUTSIDE any Obsidian vault.

    Precedence: SESSION_JOURNAL_STATE → $XDG_STATE_HOME/session-journal →
    ~/.local/state/session-journal. Keeping raw here means the bulky append-only
    trail never enters the vault (and never syncs via Obsidian Sync).
    """
    explicit = os.environ.get("SESSION_JOURNAL_STATE")
    if explicit:
        return expand(explicit)
    xdg = os.environ.get("XDG_STATE_HOME")
    base = pathlib.Path(xdg).expanduser() if xdg else pathlib.Path.home() / ".local" / "state"
    return (base / "session-journal").resolve()


def raw_path_for(session_id: str) -> pathlib.Path:
    return state_root() / "Raw" / today() / f"{session_id}.jsonl"


def prune_raw(retention_days: int | None = None) -> None:
    """Delete Raw/<date>/ dirs older than the retention window. Best-effort."""
    if retention_days is None:
        try:
            retention_days = int(os.environ.get("SESSION_JOURNAL_RAW_RETENTION_DAYS", DEFAULT_RAW_RETENTION_DAYS))
        except ValueError:
            retention_days = DEFAULT_RAW_RETENTION_DAYS
    raw_root = state_root() / "Raw"
    if not raw_root.is_dir():
        return
    cutoff = dt.date.today() - dt.timedelta(days=retention_days)
    for date_dir in raw_root.iterdir():
        if not date_dir.is_dir():
            continue
        try:
            d = dt.datetime.strptime(date_dir.name, "%Y-%m-%d").date()
        except ValueError:
            continue
        if d < cutoff:
            shutil.rmtree(date_dir, ignore_errors=True)
```

- [ ] **Step 2: Repoint `paths_for` / drop in-vault Raw + Sessions**

Replace `paths_for` (lines 230-234) with:

```python
def paths_for(vault: pathlib.Path, session_id: str) -> dict[str, pathlib.Path]:
    return {
        "daily": daily_note_path(vault),
        "raw": raw_path_for(session_id),
    }


def daily_note_path(vault: pathlib.Path) -> pathlib.Path:
    return vault / DAILY_DIR / f"{today()}.md"
```

- [ ] **Step 3: Stop creating in-vault `Sessions/`/`Raw/` in `ensure_layout`**

Replace the loop in `ensure_layout` (line 208) `for rel in ("Sessions", "Raw", ".obsidian"):` with `for rel in (DAILY_DIR, ".obsidian"):` and update the `Index.md` body text to describe the new layout (Journal/ daily notes; raw lives outside the vault). New Index body paragraph:

```python
            "Daily session logs live under `Journal/` — one note per day holding a "
            "chronological, upsert-able summary block per *meaningful* session "
            "(throwaway sessions are skipped). The bulky append-only raw event log "
            "lives OUTSIDE this vault (under `$XDG_STATE_HOME/session-journal/Raw/`). "
            "Durable knowledge is curated on demand by the `/session-journal` skill "
            "or research-engine `/wiki`, not written here.\n",
```

- [ ] **Step 4: Run the test — expect it to advance past the raw/vault checks but still fail on the daily-note block**

Run: `bash tests/session-journal/self-test.sh`
Expected: still FAIL (no daily-note upsert yet), but `test ! -d "${VAULT}/Raw"` and `find ${STATE}/Raw ...` now pass.

---

### Task 3: Daily note upsert + meaningful-session gate + per-session block

**Files:**
- Modify: `shared/session-journal/session_journal_core.py`

- [ ] **Step 1: Add the meaningful gate + block builder + upsert** (replace `init_session_note`, lines 261-282, with the functions below; keep `wikilinks`, `first_nonempty`, `load_raw`)

```python
TMP_CWD_MARKERS = ("/tmp/", "/private/tmp/", "/var/folders/")


def is_trivial_cwd(cwd: str | None) -> bool:
    if not cwd:
        return True
    c = cwd if cwd.endswith("/") else cwd + "/"
    return any(marker in c for marker in TMP_CWD_MARKERS)


def session_is_meaningful(events: list[dict[str, Any]], cwd: str | None) -> bool:
    if is_trivial_cwd(cwd):
        return False
    has_prompt = has_tool = has_result = False
    for record in events:
        event = record.get("event", {})
        if not isinstance(event, dict):
            continue
        name = event.get("hook_event_name") or record.get("hook_event_name")
        if name == "UserPromptSubmit" and first_nonempty(str(event.get("prompt") or "")):
            has_prompt = True
        elif name == "PostToolUse" and event.get("tool_name"):
            has_tool = True
        elif name == "Stop" and first_nonempty(str(event.get("last_assistant_message") or "")):
            has_result = True
    return has_prompt and (has_tool or has_result)


def session_started_at(events: list[dict[str, Any]]) -> str:
    for record in events:
        ts = record.get("recorded_at")
        if isinstance(ts, str) and len(ts) >= 16:
            return ts[11:16]  # HH:MM
    return now_iso()[11:16]


def build_session_block(events: list[dict[str, Any]], agent: str, cwd: str | None) -> str:
    prompts: list[str] = []
    results: list[str] = []
    tools: list[str] = []
    for record in events:
        event = record.get("event", {})
        if not isinstance(event, dict):
            continue
        name = event.get("hook_event_name") or record.get("hook_event_name")
        if name == "UserPromptSubmit" and isinstance(event.get("prompt"), str):
            line = first_nonempty(event["prompt"])
            if line:
                prompts.append(line)
        elif name == "Stop" and isinstance(event.get("last_assistant_message"), str):
            line = first_nonempty(event["last_assistant_message"])
            if line:
                results.append(line)
        elif name == "PostToolUse" and event.get("tool_name"):
            tools.append(str(event["tool_name"]))

    workspace = pathlib.Path(cwd).name if cwd else "unknown-workspace"
    lines = [f"### {session_started_at(events)} — {workspace} · {agent}",
             f"[[{agent}]] · [[{workspace}]]", ""]
    for item in prompts[-5:]:
        lines.append(f"- prompt: {item}")
    for item in results[-3:]:
        lines.append(f"- result: {item}")
    if tools:
        lines.append(f"- tools: {', '.join(sorted(set(tools[-20:])))}")
    lines.extend(["", f"Related: {' '.join(wikilinks(cwd))}"])
    return "\n".join(lines).strip() + "\n"


def ensure_daily_note(path: pathlib.Path) -> None:
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    date = path.stem
    path.write_text(
        "---\n"
        "type: journal\n"
        f"date: {date}\n"
        f"{tags_block()}"
        "---\n\n"
        f"# Journal {date}\n\n"
        "> [!info] 🤖 AI-generated — chronological summaries of meaningful "
        "Claude Code / Codex sessions on this day. Filter with `tag:#ai-generated`. "
        "Full raw logs live outside the vault.\n\n",
        encoding="utf-8",
    )


def upsert_session_block(daily_path: pathlib.Path, session_id: str, block: str) -> None:
    ensure_daily_note(daily_path)
    start = f"<!-- session:{session_id}:start -->"
    end = f"<!-- session:{session_id}:end -->"
    wrapped = f"{start}\n{block}{end}\n"
    text = daily_path.read_text(encoding="utf-8")
    if start in text and end in text:
        pattern = re.compile(re.escape(start) + r".*?" + re.escape(end) + r"\n?", re.S)
        text = pattern.sub(wrapped, text, count=1)
    else:
        text = text.rstrip() + "\n\n" + wrapped
    daily_path.write_text(text, encoding="utf-8")
```

- [ ] **Step 2: Rewrite `handle_event`** (lines 353-379) to use the daily note + external raw + gate

```python
def handle_event(event: dict[str, Any], agent: str, vault: pathlib.Path) -> dict[str, Any]:
    ensure_layout(vault)
    event = redact(event)
    session_id = safe_id(event.get("session_id"))
    raw = raw_path_for(session_id)
    daily = daily_note_path(vault)

    if event.get("hook_event_name") == "SessionStart":
        prune_raw()

    append_raw(raw, {"recorded_at": now_iso(), "agent": agent, "event": event})

    recorded = False
    if event.get("hook_event_name") in {"Stop", "UserPromptSubmit"}:
        events = load_raw(raw)
        cwd = event.get("cwd")
        if not cwd:
            for rec in events:
                ev = rec.get("event", {})
                if isinstance(ev, dict) and isinstance(ev.get("cwd"), str):
                    cwd = ev["cwd"]
                    break
        if session_is_meaningful(events, cwd):
            upsert_session_block(daily, session_id, build_session_block(events, agent, cwd))
            recorded = True

    return {
        "session_id": session_id,
        "vault": str(vault),
        "daily_note": str(daily),
        "raw_log": str(raw),
        "recorded": recorded,
    }
```

- [ ] **Step 3: Run the test — expect daily-note + upsert checks to pass now**

Run: `bash tests/session-journal/self-test.sh`
Expected: PASS through checks 1-6 (still fails on `summarize` check 7 until Task 4).

---

### Task 4: Fix `summarize_session`, `run_self_test`, `diagnose` for the new layout

**Files:**
- Modify: `shared/session-journal/session_journal_core.py`

- [ ] **Step 1: Rewrite `summarize_session`** (lines 382-397) to read external raw + upsert into the right daily note

```python
def summarize_session(session_id: str, vault: pathlib.Path) -> dict[str, Any]:
    safe = safe_id(session_id)
    raw_paths = sorted((state_root() / "Raw").glob(f"*/{safe}.jsonl"))
    if not raw_paths:
        raise SystemExit(f"session not found: {safe}")
    raw = raw_paths[-1]
    date = raw.parent.name
    events = load_raw(raw)
    cwd = None
    agent = "agent"
    for record in events:
        event = record.get("event", {})
        if isinstance(event, dict) and isinstance(event.get("cwd"), str) and cwd is None:
            cwd = event["cwd"]
        if isinstance(record.get("agent"), str):
            agent = record["agent"]
    daily = vault / DAILY_DIR / f"{date}.md"
    upsert_session_block(daily, safe, build_session_block(events, agent, cwd))
    return {"daily_note": str(daily), "raw_log": str(raw)}
```

- [ ] **Step 2: Rewrite `run_self_test`** (lines 400-442) to a meaningful + trivial pair

```python
def run_self_test(vault: pathlib.Path) -> dict[str, Any]:
    events = [
        {"session_id": "self-test-codex", "hook_event_name": "SessionStart",
         "cwd": "/Users/dev/gprecious-marketplace", "model": "gpt-5", "source": "startup"},
        {"session_id": "self-test-codex", "hook_event_name": "UserPromptSubmit",
         "cwd": "/Users/dev/gprecious-marketplace",
         "prompt": "Implement session-journal capture for [[research-engine]] work."},
        {"session_id": "self-test-codex", "hook_event_name": "PostToolUse",
         "cwd": "/Users/dev/gprecious-marketplace", "tool_name": "Bash"},
        {"session_id": "self-test-codex", "hook_event_name": "Stop",
         "cwd": "/Users/dev/gprecious-marketplace",
         "last_assistant_message": "Done. Daily journal note holds one block per meaningful session."},
        {"session_id": "self-test-trivial", "hook_event_name": "SessionStart", "cwd": "/tmp/scratch"},
        {"session_id": "self-test-trivial", "hook_event_name": "Stop", "cwd": "/tmp/scratch",
         "last_assistant_message": "ok"},
    ]
    results = []
    for item in events:
        agent = "Codex" if "codex" in item["session_id"] else "Claude Code"
        results.append(handle_event(item, agent, vault))
    return {"vault": str(vault), "events": len(events), "results": results}
```

- [ ] **Step 3: Extend `diagnose`** (line 466 `return {`) with the raw root + retention so `where` reports it

Add these keys to the dict returned by `diagnose`:

```python
        "raw_root": str(state_root() / "Raw"),
        "raw_retention_days": os.environ.get("SESSION_JOURNAL_RAW_RETENTION_DAYS", str(DEFAULT_RAW_RETENTION_DAYS)),
```

- [ ] **Step 4: Run the full integration test — expect PASS**

Run: `bash tests/session-journal/self-test.sh`
Expected: `session-journal self-test passed: vault=... state=...`

- [ ] **Step 5: Run the core self-test subcommand against a temp vault as a second check**

Run:
```bash
T=$(mktemp -d); LLM_OBSIDIAN_VAULT="$T/v" SESSION_JOURNAL_STATE="$T/s" \
  python3 shared/session-journal/session_journal_core.py self-test --vault "$T/v" | python3 -m json.tool >/dev/null \
  && test ! -d "$T/v/Sessions" && test ! -d "$T/v/Raw" && test -f "$T/v/Journal/$(date +%Y-%m-%d).md" \
  && grep -q 'self-test-codex' "$T/v/Journal/$(date +%Y-%m-%d).md" \
  && ! grep -q 'self-test-trivial' "$T/v/Journal/$(date +%Y-%m-%d).md" \
  && echo CORE-SELFTEST-OK; rm -rf "$T"
```
Expected: `CORE-SELFTEST-OK`

- [ ] **Step 6: Commit the core + test**

```bash
git add shared/session-journal/session_journal_core.py tests/session-journal/self-test.sh
git commit -m "feat(session-journal): daily journal note + external raw log + meaningful-session gate"
```

---

### Task 5: Sync docs / SKILL / README across both trees

**Files:**
- Modify: `docs/session-journal.md`
- Modify: `claude-plugins/session-journal/skills/session-journal/SKILL.md`
- Modify: `.agents/plugins/plugins/session-journal/skills/session-journal/SKILL.md`
- Modify: `claude-plugins/session-journal/README.md`
- Modify: `.agents/plugins/plugins/session-journal/README.md`

- [ ] **Step 1: Update `docs/session-journal.md` "Vault Layout" + add raw/retention note**

Replace the `## Vault Layout` code block + bullets with:

```text
Index.md
Journal/YYYY-MM-DD.md      # one daily note: a chronological summary block per
                           # MEANINGFUL session (throwaway sessions skipped)
```

And add a `## Raw Logs (outside the vault)` section stating raw JSONL lives under
`$SESSION_JOURNAL_STATE` → `$XDG_STATE_HOME/session-journal/Raw/` → `~/.local/state/session-journal/Raw/`,
pruned past `SESSION_JOURNAL_RAW_RETENTION_DAYS` (default 30), and that summaries are rebuilt from it.

- [ ] **Step 2: Update both `SKILL.md` files** to describe the daily-note layout and external raw, **preserving any platform-specific block** (e.g. the codex `bin/`/wrapper path-resolution block if present — diff the two first and keep intentional differences).

- [ ] **Step 3: Update both `README.md` files** one-liner layout (`Journal/<date>.md` + external raw).

- [ ] **Step 4: Commit docs**

```bash
git add docs/session-journal.md claude-plugins/session-journal .agents/plugins/plugins/session-journal
git commit -m "docs(session-journal): document daily-note layout + external raw"
```

---

### Task 6: Bump both plugin versions and pass the dual-tree gate

**Files:**
- Modify: `claude-plugins/session-journal/.claude-plugin/plugin.json` (`version` + `description`)
- Modify: `.agents/plugins/plugins/session-journal/.codex-plugin/plugin.json` (`version` + `description`)

- [ ] **Step 1: Bump both `version` `0.5.0` → `0.6.0`** and update each `description` to mention "daily journal note" + "raw log outside the vault". Update the codex `interface.longDescription` to match.

- [ ] **Step 2: Run the dual-tree gate**

Run: `python3 scripts/dual-tree-check.py`
Expected: `OK: 버전 skew 없음` (no SKEW line for session-journal).

- [ ] **Step 3: Commit the bump**

```bash
git add claude-plugins/session-journal/.claude-plugin/plugin.json .agents/plugins/plugins/session-journal/.codex-plugin/plugin.json
git commit -m "chore(session-journal): bump 0.5.0 -> 0.6.0 (daily note + external raw)"
```

---

## Self-Review

**Spec coverage:** ① daily single note, meaningful-only → Task 3 gate + upsert. ② raw outside vault + retention → Task 2. ③ name-based portability → unchanged code (verified separately in machine-config step) + diagnose now reports raw root. ④ tests/dual-tree/docs → Tasks 1,4,5,6. research-engine auto-wiki + data deletion + settings switch are explicitly deferred (Plan B + cleanup step).

**Placeholder scan:** none — every code/test step shows full content.

**Type consistency:** `daily_note_path`, `raw_path_for`, `state_root`, `build_session_block`, `upsert_session_block`, `session_is_meaningful`, `is_trivial_cwd`, `session_started_at`, `prune_raw` are defined in Task 2/3 and used consistently in `handle_event`/`summarize_session`/`run_self_test`. `paths_for` keys (`daily`,`raw`) match usage. Return dict key `daily_note` matches the self-test grep in Task 1 (check 7).

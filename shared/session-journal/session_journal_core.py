#!/usr/bin/env python3
"""Shared Obsidian session journal core for Claude Code and Codex hooks.

Capture-only by design: the hook is pure Python (no LLM), so it records a
lightweight, append-only trail and a mechanical per-session summary — it does
NOT try to author "knowledge". Two outputs:

* ``<state>/Raw/<date>/<id>.jsonl`` — append-only full event log (source of
  truth), kept OUTSIDE the Obsidian vault (under ``$XDG_STATE_HOME/session-journal``)
  with retention, so the bulky trail never syncs.
* ``<vault>/Journal/<date>.md`` — one daily note with a chronological,
  upsert-able summary block per *meaningful* session (throwaway sessions are
  skipped; no verbatim transcript — the full text lives in Raw).

Durable wiki curation (distilling lessons / reusable knowledge) is an LLM task
handled on demand by the ``/session-journal`` skill or by research-engine
``/wiki`` — never auto-generated here, which only ever produced noise.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import unicodedata
import urllib.error
import urllib.request
from typing import Any


DEFAULT_VAULT = "~/Documents/Obsidian/llm-agent-vault"
DEFAULT_WIKI_SUBDIR = "LLM-Wiki"
RELATED_KEYWORDS = [
    "Claude Code",
    "Codex",
    "research-engine",
    "dream",
    "evolve",
    "herdr",
    "session-journal",
    "Obsidian",
]
# Tags stamped on every generated note so AI-authored content stays clearly
# distinguishable from a user's own notes when the vault is shared (e.g. a
# subfolder inside an existing Obsidian Sync vault). Filter/exclude in Obsidian
# search or graph with `tag:#ai-generated`.
AI_TAGS = ("ai-generated", "session-journal")
# The journal is one note per day (Journal/<date>.md) holding a chronological,
# upsert-able summary block per *meaningful* session — not one file per session.
DAILY_DIR = "Journal"
DEFAULT_RAW_RETENTION_DAYS = 30


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).astimezone().isoformat(timespec="seconds")


def today() -> str:
    return dt.datetime.now().strftime("%Y-%m-%d")


def tags_block() -> str:
    """YAML frontmatter ``tags:`` list marking a note as AI-generated."""
    return "tags:\n" + "".join(f"  - {tag}\n" for tag in AI_TAGS)


def expand(path: str) -> pathlib.Path:
    return pathlib.Path(path).expanduser().resolve()


def state_root() -> pathlib.Path:
    """Where raw JSONL logs live — OUTSIDE any Obsidian vault.

    Precedence: SESSION_JOURNAL_STATE -> $XDG_STATE_HOME/session-journal ->
    ~/.local/state/session-journal. Keeping the bulky append-only trail here means
    it never enters the vault (and never syncs via Obsidian Sync); the readable
    daily note in the vault is rebuilt from it.
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
            retention_days = int(
                os.environ.get("SESSION_JOURNAL_RAW_RETENTION_DAYS", str(DEFAULT_RAW_RETENTION_DAYS))
            )
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


def obsidian_config_paths() -> list[pathlib.Path]:
    """Where the Obsidian desktop app records its known vaults, per OS."""
    home = pathlib.Path.home()
    paths = [
        home / "Library" / "Application Support" / "obsidian" / "obsidian.json",  # macOS
        home / ".config" / "obsidian" / "obsidian.json",                          # Linux
    ]
    appdata = os.environ.get("APPDATA")
    if appdata:
        paths.append(pathlib.Path(appdata) / "obsidian" / "obsidian.json")        # Windows
    return paths


def named_vault_candidates(name: str) -> list[pathlib.Path]:
    """All registered Obsidian vaults whose folder name matches ``name``.

    More than one match means the machine has several same-named vaults (e.g. a
    live local copy plus a stale iCloud copy) — name resolution would then flip
    between them depending on which was last open, splitting writes. Pin
    ``LLM_OBSIDIAN_VAULT`` to an absolute path to avoid that.
    """
    found: list[pathlib.Path] = []
    seen: set[str] = set()
    for cfg in obsidian_config_paths():
        try:
            if not cfg.is_file():
                continue
            vaults = json.loads(cfg.read_text(encoding="utf-8")).get("vaults")
        except (OSError, json.JSONDecodeError, AttributeError):
            continue
        if not isinstance(vaults, dict):
            continue
        for info in vaults.values():
            if not isinstance(info, dict):
                continue
            path = info.get("path")
            if not isinstance(path, str) or pathlib.Path(path).name != name:
                continue
            resolved = pathlib.Path(path).expanduser()
            key = str(resolved)
            if key not in seen:
                seen.add(key)
                found.append(resolved)
    return found


def resolve_named_vault(name: str) -> pathlib.Path | None:
    """Resolve an Obsidian vault by NAME to its machine-local absolute path.

    The same synced vault (e.g. via Obsidian Sync) has a different absolute path
    on each machine, but its name is stable — so a name-based config is portable:
    the same env works everywhere and each machine reads its own `obsidian.json`.
    Prefers an open vault, then the most recently used. Returns None when Obsidian
    or the named vault is not registered on this machine.
    """
    best: tuple[int, int] | None = None
    best_path: pathlib.Path | None = None
    for cfg in obsidian_config_paths():
        try:
            if not cfg.is_file():
                continue
            vaults = json.loads(cfg.read_text(encoding="utf-8")).get("vaults")
        except (OSError, json.JSONDecodeError, AttributeError):
            continue
        if not isinstance(vaults, dict):
            continue
        for info in vaults.values():
            if not isinstance(info, dict):
                continue
            path = info.get("path")
            if not isinstance(path, str) or pathlib.Path(path).name != name:
                continue
            rank = (int(bool(info.get("open"))), int(info.get("ts") or 0))
            if best is None or rank > best:
                best, best_path = rank, pathlib.Path(path).expanduser()
    return best_path


def vault_root(explicit: str | None = None) -> pathlib.Path:
    if explicit:
        return expand(explicit)
    env_path = os.environ.get("LLM_OBSIDIAN_VAULT")
    if env_path:
        return expand(env_path)
    # Portable multi-machine config: resolve a named Obsidian vault and descend
    # into an optional subfolder. The vault content travels between machines via
    # Obsidian Sync; this resolves the right local path on whichever machine runs.
    name = os.environ.get("LLM_OBSIDIAN_VAULT_NAME")
    if name:
        resolved = resolve_named_vault(name)
        if resolved:
            subdir = (os.environ.get("LLM_OBSIDIAN_SUBDIR") or "").strip("/")
            return (resolved / subdir).resolve() if subdir else resolved.resolve()
    return expand(DEFAULT_VAULT)


def clean_subdir(value: str | None, default: str) -> str:
    text = str(value or default).strip("/")
    return text or default


def wiki_vault_root(explicit: str | None = None) -> pathlib.Path:
    """Resolve the curated LLM wiki vault.

    This intentionally follows research-engine's wiki targeting policy:
    explicit WIKI_VAULT first, then an Obsidian vault name plus LLM_WIKI_SUBDIR
    (default LLM-Wiki), then a local ./wiki fallback.
    """
    if explicit:
        return expand(explicit)
    env_path = os.environ.get("WIKI_VAULT")
    if env_path:
        return expand(env_path)
    name = os.environ.get("LLM_OBSIDIAN_VAULT_NAME")
    if name:
        resolved = resolve_named_vault(name)
        if resolved:
            return (resolved / clean_subdir(os.environ.get("LLM_WIKI_SUBDIR"), DEFAULT_WIKI_SUBDIR)).resolve()
    return (pathlib.Path.cwd() / "wiki").resolve()


def safe_id(value: Any, fallback: str = "unknown-session") -> str:
    text = str(value or "").strip() or fallback
    text = re.sub(r"[^A-Za-z0-9_.:-]+", "-", text)
    return text.strip("-")[:120] or fallback


def slugify(value: Any, fallback: str = "lesson") -> str:
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = text.encode("ascii", "ignore").decode("ascii").lower()
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return text[:80].strip("-") or fallback


def yaml_string(value: Any) -> str:
    return json.dumps(str(value or ""), ensure_ascii=False)


def read_json_stdin() -> dict[str, Any]:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        return {
            "hook_event_name": "InvalidJson",
            "raw_stdin": raw[:4000],
            "parse_error": str(exc),
        }
    return data if isinstance(data, dict) else {"value": data}


def redact(value: Any) -> Any:
    if isinstance(value, dict):
        out: dict[str, Any] = {}
        for key, item in value.items():
            if re.search(r"(token|secret|password|credential|api[_-]?key)", str(key), re.I):
                out[key] = "[REDACTED]"
            else:
                out[key] = redact(item)
        return out
    if isinstance(value, list):
        return [redact(item) for item in value]
    if isinstance(value, str):
        patterns = [
            r"sk-[A-Za-z0-9_-]{20,}",
            r"secret_[A-Za-z0-9_-]+",
            r"(?i)(api[_-]?key|token|password|secret)\s*[:=]\s*[^\s]+",
        ]
        text = value
        for pattern in patterns:
            text = re.sub(pattern, "[REDACTED]", text)
        return text
    return value


def ensure_layout(vault: pathlib.Path) -> None:
    for rel in (DAILY_DIR, ".obsidian"):
        (vault / rel).mkdir(parents=True, exist_ok=True)
    index = vault / "Index.md"
    if not index.exists():
        index.write_text(
            "---\n"
            "type: index\n"
            f"{tags_block()}"
            "---\n\n"
            "# LLM Agent Vault\n\n"
            "> [!info] 🤖 AI-generated\n"
            "> Every note under this folder is written by the session-journal plugin "
            "(Claude Code / Codex) and tagged `#ai-generated`. It is **not** hand-authored. "
            "Filter or exclude it from search/graph with `tag:#ai-generated`.\n\n"
            "Daily session logs live under `Journal/` — one note per day holding a "
            "chronological, upsert-able summary block per *meaningful* session "
            "(throwaway sessions are skipped). The bulky append-only raw event log "
            "lives OUTSIDE this vault (under `$XDG_STATE_HOME/session-journal/Raw/`). "
            "Durable knowledge is curated on demand by the `/session-journal` skill "
            "or research-engine `/wiki`, not written here.\n",
            encoding="utf-8",
        )


def daily_note_path(vault: pathlib.Path) -> pathlib.Path:
    return vault / DAILY_DIR / f"{today()}.md"


def paths_for(vault: pathlib.Path, session_id: str) -> dict[str, pathlib.Path]:
    return {
        "daily": daily_note_path(vault),
        "raw": raw_path_for(session_id),
    }


def wikilinks(cwd: str | None = None, extra: list[str] | None = None) -> list[str]:
    terms = list(RELATED_KEYWORDS)
    if cwd:
        repo = pathlib.Path(cwd).name
        if repo:
            terms.append(repo)
    if extra:
        terms.extend([term for term in extra if term])
    seen: set[str] = set()
    links: list[str] = []
    for term in terms:
        key = term.lower()
        if key not in seen:
            seen.add(key)
            links.append(f"[[{term}]]")
    return links


def append_raw(path: pathlib.Path, record: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")


# macOS resolves $TMPDIR to /var/folders/... (often surfaced as /private/var/folders/...)
TMP_CWD_MARKERS = ("/tmp/", "/private/tmp/", "/var/folders/", "/private/var/folders/")


def is_trivial_cwd(cwd: str | None) -> bool:
    if not cwd:
        return True
    c = cwd if cwd.endswith("/") else cwd + "/"
    return any(marker in c for marker in TMP_CWD_MARKERS)


def session_is_meaningful(events: list[dict[str, Any]], cwd: str | None) -> bool:
    """A session earns a journal block only when it is real work.

    Skips throwaway sessions (tmp cwd, no substantive prompt/result) so the daily
    note records meaningful sessions chronologically — not every session.
    """
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
    lines = [
        f"### {session_started_at(events)} — {workspace} · {agent}",
        f"[[{agent}]] · [[{workspace}]]",
        "",
    ]
    lines.extend(f"- prompt: {item}" for item in prompts[-5:])
    lines.extend(f"- result: {item}" for item in results[-3:])
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
    """Insert or replace this session's block in the daily note (idempotent).

    First-seen order is append order, so blocks read chronologically; later turns
    of the same session replace its block in place instead of duplicating it.
    """
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


def first_nonempty(text: str, limit: int = 180) -> str:
    for line in text.splitlines():
        clean = line.strip()
        if clean:
            return clean[:limit]
    return ""


def load_raw(raw_path: pathlib.Path) -> list[dict[str, Any]]:
    if not raw_path.exists():
        return []
    events: list[dict[str, Any]] = []
    for line in raw_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            item = json.loads(line)
            if isinstance(item, dict):
                events.append(item)
        except json.JSONDecodeError:
            continue
    return events


def first_cwd(events: list[dict[str, Any]], fallback: str | None = None) -> str | None:
    for record in events:
        event = record.get("event", {})
        if isinstance(event, dict) and isinstance(event.get("cwd"), str) and event["cwd"]:
            return event["cwd"]
    return fallback


def handle_event(event: dict[str, Any], agent: str, vault: pathlib.Path) -> dict[str, Any]:
    ensure_layout(vault)
    event = redact(event)
    session_id = safe_id(event.get("session_id"))
    raw = raw_path_for(session_id)
    daily = daily_note_path(vault)

    if event.get("hook_event_name") == "SessionStart":
        prune_raw()

    append_raw(raw, {"recorded_at": now_iso(), "agent": agent, "event": event})

    # The daily note holds one upsert-able block per MEANINGFUL session (the full
    # trail is already in the external Raw/). Refresh on the events that can change
    # the block; PostToolUse only extends the raw log. SessionStart has no content
    # yet, so it never writes a block.
    recorded = False
    if event.get("hook_event_name") in {"Stop", "UserPromptSubmit"}:
        events = load_raw(raw)
        cwd = first_cwd(events, event.get("cwd"))
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


def summarize_session(session_id: str, vault: pathlib.Path) -> dict[str, Any]:
    safe = safe_id(session_id)
    raw_paths = sorted((state_root() / "Raw").glob(f"*/{safe}.jsonl"))
    if not raw_paths:
        raise SystemExit(f"session not found: {safe}")
    raw = raw_paths[-1]
    date = raw.parent.name
    events = load_raw(raw)
    cwd = first_cwd(events)
    agent = "agent"
    for record in events:
        if isinstance(record.get("agent"), str):
            agent = record["agent"]
            break
    daily = vault / DAILY_DIR / f"{date}.md"
    upsert_session_block(daily, safe, build_session_block(events, agent, cwd))
    return {"daily_note": str(daily), "raw_log": str(raw)}


def load_candidate_payload(candidate_file: str | None) -> dict[str, Any]:
    if candidate_file:
        raw = pathlib.Path(candidate_file).expanduser().read_text(encoding="utf-8")
    else:
        raw = sys.stdin.read()
    if not raw.strip():
        return {"candidates": []}
    data = json.loads(raw)
    if isinstance(data, list):
        return {"candidates": data}
    if isinstance(data, dict):
        return data
    raise ValueError("candidate payload must be a JSON object or array")


def clean_link(value: Any) -> str:
    text = str(value or "").strip()
    text = re.sub(r"^\[\[|\]\]$", "", text)
    text = re.sub(r"[\r\n]+", " ", text).strip()
    return text[:100]


def clean_tag(value: Any) -> str:
    text = slugify(value, "")
    return text[:40]


def candidate_is_complete(candidate: dict[str, Any]) -> bool:
    return all(first_nonempty(str(candidate.get(key) or ""), 20) for key in ("title", "lesson", "why", "how_to_apply"))


def unique_path(directory: pathlib.Path, stem: str, suffix: str = ".md") -> pathlib.Path:
    path = directory / f"{stem}{suffix}"
    if not path.exists():
        return path
    for index in range(2, 1000):
        candidate = directory / f"{stem}-{index}{suffix}"
        if not candidate.exists():
            return candidate
    raise RuntimeError(f"too many duplicate draft names for {stem}")


def render_lesson_draft(
    *,
    candidate: dict[str, Any],
    session_id: str,
    agent: str,
    workspace: str,
    raw_log: pathlib.Path | None,
) -> tuple[str, list[str]]:
    title = first_nonempty(str(candidate.get("title") or ""), 140)
    confidence = str(candidate.get("confidence") or "medium").strip() or "medium"
    links = ["session-journal", "LLM-Wiki"]
    if workspace:
        links.append(workspace)
    if agent:
        links.append(agent)
    links.extend(candidate.get("links") or [])
    related = []
    seen: set[str] = set()
    for link in links:
        clean = clean_link(link)
        key = clean.lower()
        if clean and key not in seen:
            seen.add(key)
            related.append(clean)

    extra_tags = [clean_tag(item) for item in (candidate.get("tags") or [])]
    tags = [tag for tag in [*AI_TAGS, "llm-wiki", "lesson", *extra_tags] if tag]
    frontmatter = [
        "---",
        "type: lesson",
        f"title: {yaml_string(title)}",
        f"source: {yaml_string('session/' + session_id)}",
        f"source_session: {yaml_string(session_id)}",
        f"workspace: {yaml_string(workspace)}",
        f"agent: {yaml_string(agent)}",
        f"confidence: {yaml_string(confidence)}",
        f"created: {yaml_string(today())}",
        "tags:",
        *[f"  - {tag}" for tag in tags],
        "related:",
        *[f"  - {yaml_string('[[' + item + ']]')}" for item in related],
        "---",
        "",
    ]
    raw_line = f"- raw log: `{raw_log}`" if raw_log else "- raw log: not resolved"
    body = [
        f"# {title}",
        "",
        "> [!warning] Draft lesson candidate. Review before promoting into the live LLM-Wiki graph.",
        "",
        "## Lesson",
        str(candidate.get("lesson") or "").strip(),
        "",
        "## Why It Matters",
        str(candidate.get("why") or "").strip(),
        "",
        "## How To Apply",
        str(candidate.get("how_to_apply") or "").strip(),
        "",
        "## Source",
        f"- session: `{session_id}`",
        f"- workspace: `[[{workspace}]]`" if workspace else "- workspace: unknown",
        f"- agent: `[[{agent}]]`" if agent else "- agent: unknown",
        raw_line,
        "",
        "## Related",
        *[f"- [[{item}]]" for item in related],
        "",
    ]
    return "\n".join([*frontmatter, *body]), related


def build_slack_message(session_id: str, drafts: list[dict[str, Any]], report_path: pathlib.Path) -> str:
    lines = [
        f"{len(drafts)} session-journal wiki draft candidate(s) created",
        f"source session: {session_id}",
        f"report: {report_path}",
        "",
    ]
    for item in drafts:
        lines.extend([
            f"- {item['title']} ({item['confidence']})",
            f"  path: {item['path']}",
        ])
    lines.extend(["", "Review the drafts before promoting them into the live LLM-Wiki graph."])
    return "\n".join(lines).strip() + "\n"


def send_slack_report(message: str) -> dict[str, Any]:
    command = os.environ.get("SESSION_JOURNAL_SLACK_REPORT_COMMAND")
    webhook = os.environ.get("SESSION_JOURNAL_SLACK_WEBHOOK_URL")
    if command:
        try:
            completed = subprocess.run(
                shlex.split(command),
                input=message,
                text=True,
                capture_output=True,
                timeout=20,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return {"sent": False, "method": "command", "error": str(exc)}
        if completed.returncode == 0:
            return {"sent": True, "method": "command"}
        return {
            "sent": False,
            "method": "command",
            "error": (completed.stderr or completed.stdout or f"exit {completed.returncode}")[:1000],
        }
    if webhook:
        payload = json.dumps({"text": message}).encode("utf-8")
        request = urllib.request.Request(
            webhook,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return {"sent": 200 <= response.status < 300, "method": "webhook", "status": response.status}
        except (urllib.error.URLError, TimeoutError) as exc:
            return {"sent": False, "method": "webhook", "error": str(exc)}
    return {"sent": False, "method": "none", "reason": "Slack reporting not configured"}


def write_wiki_drafts(payload: dict[str, Any], wiki_vault: pathlib.Path) -> dict[str, Any]:
    payload = redact(payload)
    session_id = safe_id(payload.get("session_id"))
    agent = str(payload.get("agent") or "agent")
    workspace = str(payload.get("workspace") or "")
    raw_log = raw_path_for(session_id)
    raw_log_or_none = raw_log if raw_log.exists() else None
    candidates = payload.get("candidates") or []
    if not isinstance(candidates, list):
        raise ValueError("candidates must be an array")

    lessons_dir = wiki_vault / "_drafts" / "lessons"
    reports_dir = wiki_vault / "_drafts" / "reports"
    lessons_dir.mkdir(parents=True, exist_ok=True)
    reports_dir.mkdir(parents=True, exist_ok=True)

    drafts: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    for index, item in enumerate(candidates, start=1):
        if not isinstance(item, dict):
            skipped.append({"index": index, "reason": "candidate is not an object"})
            continue
        if not candidate_is_complete(item):
            skipped.append({"index": index, "reason": "missing required title/lesson/why/how_to_apply"})
            continue
        title = first_nonempty(str(item.get("title") or ""), 140)
        stem = f"{today()}-{session_id}-{slugify(title)}"
        draft_path = unique_path(lessons_dir, stem)
        content, related = render_lesson_draft(
            candidate=item,
            session_id=session_id,
            agent=agent,
            workspace=workspace,
            raw_log=raw_log_or_none,
        )
        draft_path.write_text(content, encoding="utf-8")
        drafts.append({
            "title": title,
            "path": str(draft_path),
            "confidence": str(item.get("confidence") or "medium"),
            "related": related,
        })

    report_path = unique_path(reports_dir, f"{today()}-{session_id}-wiki-draft-report")
    if drafts:
        message = build_slack_message(session_id, drafts, report_path)
    else:
        message = f"0 session-journal wiki draft candidates created\nsource session: {session_id}\n"
    report_path.write_text(message, encoding="utf-8")
    slack_report = send_slack_report(message) if drafts else {"sent": False, "method": "none", "reason": "no drafts"}
    return {
        "wiki_vault": str(wiki_vault),
        "source_session": session_id,
        "drafts": drafts,
        "skipped": skipped,
        "report": str(report_path),
        "slack_report": slack_report,
    }


def run_self_test(vault: pathlib.Path) -> dict[str, Any]:
    work = "/Users/dev/gprecious-marketplace"  # a non-tmp (meaningful) workspace
    events = [
        {"session_id": "self-test-codex", "hook_event_name": "SessionStart",
         "cwd": work, "model": "gpt-5", "source": "startup"},
        {"session_id": "self-test-codex", "hook_event_name": "UserPromptSubmit",
         "cwd": work,
         "prompt": "Implement session-journal capture for [[research-engine]] work."},
        {"session_id": "self-test-codex", "hook_event_name": "PostToolUse",
         "cwd": work, "tool_name": "Bash"},
        {"session_id": "self-test-codex", "hook_event_name": "Stop",
         "cwd": work,
         "last_assistant_message": "Done. Daily journal note holds one block per meaningful session."},
        # Throwaway session (tmp cwd, no real prompt) — must be skipped.
        {"session_id": "self-test-trivial", "hook_event_name": "SessionStart", "cwd": "/tmp/scratch"},
        {"session_id": "self-test-trivial", "hook_event_name": "Stop", "cwd": "/tmp/scratch",
         "last_assistant_message": "ok"},
    ]
    results = []
    for item in events:
        agent = "Codex" if "codex" in item["session_id"] else "Claude Code"
        results.append(handle_event(item, agent, vault))
    return {"vault": str(vault), "events": len(events), "results": results}


def diagnose(vault: pathlib.Path) -> dict[str, Any]:
    """Report how the vault path was resolved — for verifying per-machine setup."""
    explicit = os.environ.get("LLM_OBSIDIAN_VAULT")
    name = os.environ.get("LLM_OBSIDIAN_VAULT_NAME")
    candidates = named_vault_candidates(name) if name else []
    named = resolve_named_vault(name) if name else None
    if explicit:
        mode = "explicit (LLM_OBSIDIAN_VAULT)"
    elif name and named:
        mode = "name (LLM_OBSIDIAN_VAULT_NAME)"
    elif name:
        mode = "default (named vault NOT found on this machine — check Obsidian is set up)"
    else:
        mode = "default (no env set)"
    warnings: list[str] = []
    if not explicit and len(candidates) > 1:
        warnings.append(
            f"{len(candidates)} vaults named '{name}' are registered "
            f"({', '.join(str(c) for c in candidates)}); name resolution may flip "
            "between them. Pin LLM_OBSIDIAN_VAULT to an absolute path."
        )
    return {
        "resolved_vault": str(vault),
        "vault_exists": vault.exists(),
        "resolution_mode": mode,
        "env": {
            "LLM_OBSIDIAN_VAULT": explicit,
            "LLM_OBSIDIAN_VAULT_NAME": name,
            "LLM_OBSIDIAN_SUBDIR": os.environ.get("LLM_OBSIDIAN_SUBDIR"),
        },
        "named_vault_path": str(named) if named else None,
        "named_vault_candidates": [str(c) for c in candidates],
        "obsidian_config_found": [str(p) for p in obsidian_config_paths() if p.is_file()],
        "raw_root": str(state_root() / "Raw"),
        "raw_retention_days": os.environ.get(
            "SESSION_JOURNAL_RAW_RETENTION_DAYS", str(DEFAULT_RAW_RETENTION_DAYS)
        ),
        "warnings": warnings,
        "ok": bool(explicit or named),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Obsidian session journal hook core")
    sub = parser.add_subparsers(dest="command", required=True)

    hook = sub.add_parser("hook")
    hook.add_argument("--agent", default=os.environ.get("SESSION_JOURNAL_AGENT", "agent"))
    hook.add_argument("--vault")

    summary = sub.add_parser("summarize")
    summary.add_argument("--session-id", required=True)
    summary.add_argument("--vault")

    self_test = sub.add_parser("self-test")
    self_test.add_argument("--vault")

    where = sub.add_parser("where")
    where.add_argument("--vault")

    wiki_draft = sub.add_parser("wiki-draft")
    wiki_draft.add_argument("--wiki-vault")
    wiki_draft.add_argument("--candidate-file")

    args = parser.parse_args(argv)
    vault = vault_root(getattr(args, "vault", None))

    if args.command == "where":
        print(json.dumps(diagnose(vault), ensure_ascii=False, indent=2))
        return 0
    if args.command == "hook":
        handle_event(read_json_stdin(), args.agent, vault)
        print("{}")
        return 0
    if args.command == "summarize":
        print(json.dumps(summarize_session(args.session_id, vault), ensure_ascii=False))
        return 0
    if args.command == "self-test":
        print(json.dumps(run_self_test(vault), ensure_ascii=False))
        return 0
    if args.command == "wiki-draft":
        print(json.dumps(
            write_wiki_drafts(load_candidate_payload(args.candidate_file), wiki_vault_root(args.wiki_vault)),
            ensure_ascii=False,
            indent=2,
        ))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

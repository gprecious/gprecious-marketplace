#!/usr/bin/env python3
"""Shared Obsidian session journal core for Claude Code and Codex hooks.

Capture-only by design: the hook is pure Python (no LLM), so it records a
lightweight, append-only trail and a mechanical per-session summary — it does
NOT try to author "knowledge". Two outputs per session:

* ``Raw/<date>/<id>.jsonl`` — append-only full event log (source of truth).
* ``Sessions/<date>/<id>.md`` — a single regenerated summary block (no verbatim
  transcript; the full text lives in Raw).

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
import sys
from typing import Any


DEFAULT_VAULT = "~/Documents/Obsidian/llm-agent-vault"
SECTION_START = "<!-- session-journal-summary:start -->"
SECTION_END = "<!-- session-journal-summary:end -->"
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


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).astimezone().isoformat(timespec="seconds")


def today() -> str:
    return dt.datetime.now().strftime("%Y-%m-%d")


def tags_block() -> str:
    """YAML frontmatter ``tags:`` list marking a note as AI-generated."""
    return "tags:\n" + "".join(f"  - {tag}\n" for tag in AI_TAGS)


def expand(path: str) -> pathlib.Path:
    return pathlib.Path(path).expanduser().resolve()


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


def safe_id(value: Any, fallback: str = "unknown-session") -> str:
    text = str(value or "").strip() or fallback
    text = re.sub(r"[^A-Za-z0-9_.:-]+", "-", text)
    return text.strip("-")[:120] or fallback


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
    for rel in ("Sessions", "Raw", ".obsidian"):
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
            "Session notes live under `Sessions/` (one per session — a regenerated "
            "summary block only, not a verbatim transcript). The full append-only "
            "event log lives under `Raw/`. Durable knowledge is curated on demand by "
            "the `/session-journal` skill or research-engine `/wiki`, not written here.\n",
            encoding="utf-8",
        )


def paths_for(vault: pathlib.Path, session_id: str) -> dict[str, pathlib.Path]:
    date = today()
    session = vault / "Sessions" / date / f"{session_id}.md"
    raw = vault / "Raw" / date / f"{session_id}.jsonl"
    return {"session": session, "raw": raw}


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


def init_session_note(path: pathlib.Path, session_id: str, event: dict[str, Any], agent: str) -> None:
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    cwd = event.get("cwd") or ""
    path.write_text(
        "---\n"
        f"session_id: {session_id}\n"
        f"agent: {agent}\n"
        f"created: {now_iso()}\n"
        f"cwd: {json.dumps(cwd)}\n"
        f"{tags_block()}"
        "---\n\n"
        f"# Session {session_id}\n\n"
        f"Agent: [[{agent}]]\n\n"
        f"Workspace: [[{pathlib.Path(cwd).name if cwd else 'unknown-workspace'}]]\n\n"
        f"Related: {' '.join(wikilinks(cwd))}\n\n"
        f"{SECTION_START}\n"
        "No summary yet.\n"
        f"{SECTION_END}\n",
        encoding="utf-8",
    )


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


def build_summary(events: list[dict[str, Any]], cwd: str | None = None) -> str:
    prompts: list[str] = []
    results: list[str] = []
    tools: list[str] = []
    for record in events:
        event = record.get("event", {})
        if not isinstance(event, dict):
            continue
        name = event.get("hook_event_name") or record.get("hook_event_name")
        if name == "UserPromptSubmit" and isinstance(event.get("prompt"), str):
            prompts.append(first_nonempty(event["prompt"]))
        elif name == "Stop" and isinstance(event.get("last_assistant_message"), str):
            results.append(first_nonempty(event["last_assistant_message"]))
        elif name == "PostToolUse":
            tool_name = event.get("tool_name")
            if tool_name:
                tools.append(str(tool_name))

    lines = ["### Current Summary", ""]
    if prompts:
        lines.append("User prompts:")
        lines.extend(f"- {item}" for item in prompts[-5:] if item)
    if results:
        lines.append("")
        lines.append("Agent results:")
        lines.extend(f"- {item}" for item in results[-5:] if item)
    if tools:
        recent = ", ".join(sorted(set(tools[-20:])))
        lines.extend(["", f"Recent tool activity: {recent}"])
    lines.extend(["", f"Related: {' '.join(wikilinks(cwd))}"])
    return "\n".join(lines).strip() + "\n"


def replace_summary(path: pathlib.Path, summary: str) -> None:
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    block = f"{SECTION_START}\n{summary}{SECTION_END}"
    if SECTION_START in text and SECTION_END in text:
        pattern = re.compile(re.escape(SECTION_START) + r".*?" + re.escape(SECTION_END), re.S)
        text = pattern.sub(block, text, count=1)
    else:
        text = text.rstrip() + "\n\n" + block + "\n"
    path.write_text(text, encoding="utf-8")


def handle_event(event: dict[str, Any], agent: str, vault: pathlib.Path) -> dict[str, Any]:
    ensure_layout(vault)
    event = redact(event)
    session_id = safe_id(event.get("session_id"))
    paths = paths_for(vault, session_id)
    init_session_note(paths["session"], session_id, event, agent)

    record = {
        "recorded_at": now_iso(),
        "agent": agent,
        "event": event,
    }
    append_raw(paths["raw"], record)

    # The session note carries a single regenerated summary block — no verbatim
    # event-by-event append (the full trail is already in Raw/). Refresh it on the
    # events that change the summary; PostToolUse only extends the raw log.
    if event.get("hook_event_name") in {"Stop", "UserPromptSubmit", "SessionStart"}:
        events = load_raw(paths["raw"])
        replace_summary(paths["session"], build_summary(events, event.get("cwd")))

    return {
        "session_id": session_id,
        "vault": str(vault),
        "session_note": str(paths["session"]),
        "raw_log": str(paths["raw"]),
    }


def summarize_session(session_id: str, vault: pathlib.Path) -> dict[str, Any]:
    safe = safe_id(session_id)
    session_paths = list((vault / "Sessions").glob(f"*/{safe}.md"))
    raw_paths = list((vault / "Raw").glob(f"*/{safe}.jsonl"))
    if not session_paths or not raw_paths:
        raise SystemExit(f"session not found: {safe}")
    events = load_raw(raw_paths[-1])
    cwd = None
    for record in events:
        event = record.get("event", {})
        if isinstance(event, dict) and isinstance(event.get("cwd"), str):
            cwd = event["cwd"]
            break
    summary = build_summary(events, cwd)
    replace_summary(session_paths[-1], summary)
    return {"session_note": str(session_paths[-1]), "raw_log": str(raw_paths[-1])}


def run_self_test(vault: pathlib.Path) -> dict[str, Any]:
    events = [
        {
            "session_id": "self-test-codex",
            "hook_event_name": "SessionStart",
            "cwd": "/tmp/gprecious-marketplace",
            "model": "gpt-5",
            "source": "startup",
        },
        {
            "session_id": "self-test-codex",
            "hook_event_name": "UserPromptSubmit",
            "cwd": "/tmp/gprecious-marketplace",
            "prompt": "Implement session-journal capture for [[research-engine]] work.",
            "turn_id": "turn-1",
        },
        {
            "session_id": "self-test-codex",
            "hook_event_name": "Stop",
            "cwd": "/tmp/gprecious-marketplace",
            "last_assistant_message": "Done. Shared hook core writes Obsidian summaries for [[Claude Code]] and [[Codex]].",
            "turn_id": "turn-1",
            "stop_hook_active": False,
        },
        {
            "session_id": "self-test-claude",
            "hook_event_name": "UserPromptSubmit",
            "cwd": "/tmp/gprecious-marketplace",
            "prompt": "Record this session. Raw events stay append-only and summaries are regenerated.",
        },
        {
            "session_id": "self-test-claude",
            "hook_event_name": "Stop",
            "cwd": "/tmp/gprecious-marketplace",
            "last_assistant_message": "Finished. The session note carries a summary block only.",
            "stop_hook_active": False,
        },
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

    args = parser.parse_args(argv)
    vault = vault_root(getattr(args, "vault", None))

    if args.command == "where":
        print(json.dumps(diagnose(vault), ensure_ascii=False, indent=2))
        return 0
    if args.command == "hook":
        result = handle_event(read_json_stdin(), args.agent, vault)
        print(json.dumps({"continue": True, "sessionJournal": result}, ensure_ascii=False))
        return 0
    if args.command == "summarize":
        print(json.dumps(summarize_session(args.session_id, vault), ensure_ascii=False))
        return 0
    if args.command == "self-test":
        print(json.dumps(run_self_test(vault), ensure_ascii=False))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

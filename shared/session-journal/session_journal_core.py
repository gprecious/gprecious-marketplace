#!/usr/bin/env python3
"""Shared Obsidian session journal core for Claude Code and Codex hooks."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
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
WIKI_MARKERS = (
    "wiki-worthy",
    "durable note",
    "pattern:",
    "repo convention:",
    "convention:",
    "integration:",
    "failure mode:",
    "resolved:",
    "lesson:",
)
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


def slugify(value: str, fallback: str = "note") -> str:
    text = value.strip().lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = re.sub(r"-+", "-", text).strip("-")
    return (text or fallback)[:80]


def short_hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:10]


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
    for rel in ("Sessions", "Raw", "Wiki", ".obsidian"):
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
            "- [[Claude Code]]\n"
            "- [[Codex]]\n"
            "- [[research-engine]]\n"
            "- [[dream]]\n"
            "- [[evolve]]\n"
            "- [[herdr]]\n"
            "- [[session-journal]]\n\n"
            "Session notes live under `Sessions/`; append-only raw hook events live under `Raw/`.\n",
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


def ensure_keyword_notes(vault: pathlib.Path, cwd: str | None = None) -> None:
    for link in wikilinks(cwd):
        name = link.strip("[]")
        note = vault / "Wiki" / f"{name}.md"
        if note.exists():
            continue
        note.write_text(
            "---\n"
            "type: keyword\n"
            "source: session-journal\n"
            f"{tags_block()}"
            "---\n\n"
            f"# {name}\n\n"
            f"Related: {' '.join(wikilinks(cwd))}\n",
            encoding="utf-8",
        )


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


def append_session_section(path: pathlib.Path, title: str, body: str) -> None:
    if not body.strip():
        return
    with path.open("a", encoding="utf-8") as f:
        f.write(f"\n## {title} - {now_iso()}\n\n{body.strip()}\n")


def first_nonempty(text: str, limit: int = 180) -> str:
    for line in text.splitlines():
        clean = line.strip()
        if clean:
            return clean[:limit]
    return ""


def extract_event_text(event: dict[str, Any]) -> str:
    parts: list[str] = []
    for key in ("prompt", "last_assistant_message", "message", "summary"):
        value = event.get(key)
        if isinstance(value, str):
            parts.append(value)
    tool_input = event.get("tool_input")
    if isinstance(tool_input, dict):
        command = tool_input.get("command")
        if isinstance(command, str):
            parts.append(f"Tool command: {command}")
    return "\n".join(parts)


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


def wiki_candidates(text: str) -> list[tuple[str, str]]:
    candidates: list[tuple[str, str]] = []
    for line in text.splitlines():
        clean = line.strip(" -\t")
        lower = clean.lower()
        if not clean:
            continue
        for marker in WIKI_MARKERS:
            if marker in lower:
                title = clean
                if ":" in clean:
                    title = clean.split(":", 1)[0].strip()
                title = title.replace("wiki-worthy", "Wiki-worthy").strip() or "Durable note"
                candidates.append((title[:80], clean))
                break
    return candidates


def write_wiki_notes(vault: pathlib.Path, session_id: str, event: dict[str, Any], agent: str) -> list[pathlib.Path]:
    text = extract_event_text(event)
    candidates = wiki_candidates(text)
    written: list[pathlib.Path] = []
    if not candidates:
        return written

    cwd = event.get("cwd") if isinstance(event.get("cwd"), str) else None
    session_link = f"[[Sessions/{today()}/{session_id}|session {session_id}]]"
    for title, content in candidates:
        slug = f"{slugify(title)}-{short_hash(content)}"
        path = vault / "Wiki" / f"{slug}.md"
        if path.exists():
            continue
        path.write_text(
            "---\n"
            "type: durable-note\n"
            f"created: {now_iso()}\n"
            f"agent: {agent}\n"
            f"session_id: {session_id}\n"
            f"{tags_block()}"
            "---\n\n"
            f"# {title}\n\n"
            f"Source: {session_link}\n\n"
            f"{content}\n\n"
            f"Related: {' '.join(wikilinks(cwd))}\n",
            encoding="utf-8",
        )
        written.append(path)
    return written


def event_body(event: dict[str, Any]) -> tuple[str | None, str]:
    name = event.get("hook_event_name")
    if name == "SessionStart":
        return "Session Start", f"Source: `{event.get('source', 'unknown')}`"
    if name == "UserPromptSubmit":
        return "User Prompt", str(event.get("prompt", "")).strip()
    if name == "Stop":
        return "Agent Result", str(event.get("last_assistant_message", "")).strip()
    if name == "PostToolUse":
        tool_name = event.get("tool_name", "unknown-tool")
        tool_input = event.get("tool_input", {})
        command = ""
        if isinstance(tool_input, dict) and isinstance(tool_input.get("command"), str):
            command = f"\n\nCommand:\n\n```sh\n{tool_input['command'][:2000]}\n```"
        return "Tool Result", f"Tool: `{tool_name}`{command}"
    return None, ""


def handle_event(event: dict[str, Any], agent: str, vault: pathlib.Path) -> dict[str, Any]:
    ensure_layout(vault)
    event = redact(event)
    session_id = safe_id(event.get("session_id"))
    paths = paths_for(vault, session_id)
    init_session_note(paths["session"], session_id, event, agent)
    ensure_keyword_notes(vault, event.get("cwd") if isinstance(event.get("cwd"), str) else None)

    record = {
        "recorded_at": now_iso(),
        "agent": agent,
        "event": event,
    }
    append_raw(paths["raw"], record)

    title, body = event_body(event)
    if title and body:
        append_session_section(paths["session"], title, body)

    wiki_written = write_wiki_notes(vault, session_id, event, agent)
    if wiki_written:
        links = " ".join(f"[[Wiki/{path.stem}|{path.stem}]]" for path in wiki_written)
        append_session_section(paths["session"], "Wiki Notes", links)

    if event.get("hook_event_name") in {"Stop", "UserPromptSubmit", "SessionStart"}:
        events = load_raw(paths["raw"])
        replace_summary(paths["session"], build_summary(events, event.get("cwd")))

    return {
        "session_id": session_id,
        "vault": str(vault),
        "session_note": str(paths["session"]),
        "raw_log": str(paths["raw"]),
        "wiki_notes": [str(path) for path in wiki_written],
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
            "prompt": "Implement session-journal. integration: Use [[research-engine]] dream/evolve style durable notes.",
            "turn_id": "turn-1",
        },
        {
            "session_id": "self-test-codex",
            "hook_event_name": "Stop",
            "cwd": "/tmp/gprecious-marketplace",
            "last_assistant_message": "Done. pattern: Shared hook core writes Obsidian wikilinks for [[Claude Code]] and [[Codex]].",
            "turn_id": "turn-1",
            "stop_hook_active": False,
        },
        {
            "session_id": "self-test-claude",
            "hook_event_name": "UserPromptSubmit",
            "cwd": "/tmp/gprecious-marketplace",
            "prompt": "Record this session. convention: Raw events stay append-only and summaries are regenerated.",
        },
        {
            "session_id": "self-test-claude",
            "hook_event_name": "Stop",
            "cwd": "/tmp/gprecious-marketplace",
            "last_assistant_message": "Finished. resolved: synthetic Claude event created a wiki note.",
            "stop_hook_active": False,
        },
    ]
    results = []
    for item in events:
        agent = "Codex" if "codex" in item["session_id"] else "Claude Code"
        results.append(handle_event(item, agent, vault))
    return {"vault": str(vault), "events": len(events), "results": results}


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

    args = parser.parse_args(argv)
    vault = vault_root(getattr(args, "vault", None))

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

#!/usr/bin/env python3
"""Claude Code hook wrapper for the shared session-journal core."""

from __future__ import annotations

import importlib.util
import os
import pathlib
import sys


def find_core() -> pathlib.Path:
    explicit = os.environ.get("SESSION_JOURNAL_CORE")
    if explicit:
        pinned = pathlib.Path(explicit).expanduser()
        if pinned.is_file():
            return pinned.resolve()
        # A pinned path that doesn't exist on this machine (e.g. a setting
        # synced from another machine) is ignored — fall through to discovery.

    rel = pathlib.Path("shared") / "session-journal" / "session_journal_core.py"

    def walk_up(start: pathlib.Path) -> pathlib.Path | None:
        current = start if start.is_dir() else start.parent
        for parent in [current, *current.parents]:
            candidate = parent / rel
            if candidate.exists():
                return candidate
        return None

    # 1. Walk up from the host-provided plugin roots and the wrapper's own
    #    location. The current working directory is deliberately NOT consulted
    #    here: an unrelated marketplace clone that merely happens to be the cwd
    #    (e.g. a dev checkout sitting on an old branch) must not shadow the
    #    installed core. Empty env vars are skipped.
    for env_name in ("CLAUDE_PLUGIN_ROOT", "PLUGIN_ROOT"):
        value = os.environ.get(env_name)
        if value:
            hit = walk_up(pathlib.Path(value))
            if hit:
                return hit
    hit = walk_up(pathlib.Path(__file__).resolve())
    if hit:
        return hit

    # 2. Fallback — cached/packaged plugins don't bundle `shared/`, and the hook
    #    process cwd may be anywhere. Locate the full marketplace checkout (which
    #    always ships `shared/`) under the host tool's plugin install roots, so
    #    resolution never depends on cwd.
    home = pathlib.Path.home()
    install_roots = [
        home / ".claude" / "plugins" / "marketplaces",
        home / ".config" / "claude" / "plugins" / "marketplaces",
        home / ".codex" / "plugins",
        home / ".config" / "codex" / "plugins",
    ]
    for root in install_roots:
        if not root.is_dir():
            continue
        for depth in ("*", "*/*"):
            for candidate in sorted(root.glob(f"{depth}/{rel.as_posix()}")):
                if candidate.exists():
                    return candidate

    # 3. Last resort — the current working directory. Only reached when nothing
    #    above matched, so a stray cwd can never shadow an installed core.
    hit = walk_up(pathlib.Path.cwd())
    if hit:
        return hit

    raise SystemExit("session-journal core not found")


def load_core(path: pathlib.Path):
    spec = importlib.util.spec_from_file_location("session_journal_core", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot load session-journal core: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    core = load_core(find_core())
    raise SystemExit(core.main(sys.argv[1:]))

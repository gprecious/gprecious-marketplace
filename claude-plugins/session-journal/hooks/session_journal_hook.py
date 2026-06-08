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
        return pathlib.Path(explicit).expanduser().resolve()

    rel = pathlib.Path("shared") / "session-journal" / "session_journal_core.py"

    # 1. Walk up from contextual roots — works in the dev repo and whenever the
    #    plugin root ships a `shared/` sibling (a full marketplace checkout).
    starts = [
        pathlib.Path(os.environ.get("CLAUDE_PLUGIN_ROOT", "")),
        pathlib.Path(os.environ.get("PLUGIN_ROOT", "")),
        pathlib.Path(__file__).resolve(),
        pathlib.Path.cwd(),
    ]
    for start in starts:
        if not str(start):
            continue
        current = start if start.is_dir() else start.parent
        for parent in [current, *current.parents]:
            candidate = parent / rel
            if candidate.exists():
                return candidate

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

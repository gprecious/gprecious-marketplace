#!/usr/bin/env python3
"""Codex hook wrapper for the shared session-journal core."""

from __future__ import annotations

import importlib.util
import os
import pathlib
import sys


def find_core() -> pathlib.Path:
    explicit = os.environ.get("SESSION_JOURNAL_CORE")
    if explicit:
        return pathlib.Path(explicit).expanduser().resolve()

    starts = [
        pathlib.Path(os.environ.get("PLUGIN_ROOT", "")),
        pathlib.Path(os.environ.get("CLAUDE_PLUGIN_ROOT", "")),
        pathlib.Path(__file__).resolve(),
        pathlib.Path.cwd(),
    ]
    for start in starts:
        if not str(start):
            continue
        current = start if start.is_dir() else start.parent
        for parent in [current, *current.parents]:
            candidate = parent / "shared" / "session-journal" / "session_journal_core.py"
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

#!/usr/bin/env python3
"""dual-tree-check — Claude Code 트리(claude-plugins/) ↔ Codex 트리(.agents/plugins/plugins/)
드리프트 탐지기.

이 marketplace 는 한 플러그인을 두 트리에 둔다(dual-landing):
  - Claude Code: claude-plugins/<p>/.claude-plugin/plugin.json  + skills/
  - Codex      : .agents/plugins/plugins/<p>/.codex-plugin/plugin.json + skills/
자동 동기 메커니즘이 없어, 한쪽만 고치면 다른쪽이 stale 가 된다(실측: app-release
0.1.1 vs 0.1.0). 그런데 SKILL 내용 일부는 플랫폼별로 *의도적으로* 다르다(예: codex 의
bin/wrapper 경로 해석). 따라서 이 도구는 **맹목 복사를 하지 않는다** — 차이를 보고만 하고,
사람이 의미 기준으로 reconcile 하게 한다.

종료코드:
  0 — 버전 skew 없음(경고는 있을 수 있음)
  1 — 양쪽 트리에 다 있는 플러그인의 plugin.json 버전이 어긋남(= bump 누락 의심)

사용:
  python3 scripts/dual-tree-check.py            # 리포트
  python3 scripts/dual-tree-check.py --quiet     # skew 만(게이트용)
"""
import json
import os
import sys
import difflib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLAUDE_DIR = os.path.join(ROOT, "claude-plugins")
CODEX_DIR = os.path.join(ROOT, ".agents", "plugins", "plugins")
CLAUDE_CAT = os.path.join(ROOT, ".claude-plugin", "marketplace.json")
CODEX_CAT = os.path.join(ROOT, ".agents", "plugins", "marketplace.json")

QUIET = "--quiet" in sys.argv


def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None


def version_of(path):
    d = load_json(path)
    return d.get("version") if d else None


def list_plugins(base):
    if not os.path.isdir(base):
        return set()
    return {n for n in os.listdir(base) if os.path.isdir(os.path.join(base, n))}


def skill_files(plugin_dir):
    """plugin_dir/skills/<name>/SKILL.md → {name: path}"""
    out = {}
    sk = os.path.join(plugin_dir, "skills")
    if not os.path.isdir(sk):
        return out
    for name in os.listdir(sk):
        p = os.path.join(sk, name, "SKILL.md")
        if os.path.isfile(p):
            out[name] = p
    return out


def diff_lines(a, b):
    try:
        la = open(a).read().splitlines()
        lb = open(b).read().splitlines()
    except Exception:
        return None
    return sum(1 for ln in difflib.ndiff(la, lb) if ln[:1] in "+-")


def main():
    claude = list_plugins(CLAUDE_DIR)
    codex = list_plugins(CODEX_DIR)
    both = sorted(claude & codex)

    skew = []
    skill_drift = []
    lines = []

    lines.append("dual-tree-check — Claude(claude-plugins/) ↔ Codex(.agents/plugins/plugins/)\n")

    lines.append("[1] 버전 (양쪽 트리에 다 있는 플러그인)")
    for p in both:
        cv = version_of(os.path.join(CLAUDE_DIR, p, ".claude-plugin", "plugin.json"))
        av = version_of(os.path.join(CODEX_DIR, p, ".codex-plugin", "plugin.json"))
        mark = ""
        if cv != av:
            mark = "  <-- SKEW (양쪽 bump 누락 의심)"
            skew.append((p, cv, av))
        lines.append(f"    {p:30} claude={cv!s:8} codex={av!s:8}{mark}")

    lines.append("\n[2] SKILL.md 내용 차이 (양쪽에 다 있는 skill — 의도적 차이일 수 있음, 검토만)")
    for p in both:
        cs = skill_files(os.path.join(CLAUDE_DIR, p))
        as_ = skill_files(os.path.join(CODEX_DIR, p))
        for name in sorted(set(cs) & set(as_)):
            n = diff_lines(cs[name], as_[name])
            if n:
                skill_drift.append((p, name, n))
                lines.append(f"    {p}/{name}: {n} diff lines")
    if not skill_drift:
        lines.append("    (차이 없음)")

    lines.append("\n[3] 트리 비대칭 (한쪽에만 존재 — 의도적일 수 있음: URL source / 플랫폼 전용)")
    only_c = sorted(claude - codex)
    only_a = sorted(codex - claude)
    lines.append(f"    only-in-claude-tree: {only_c or '없음'}")
    lines.append(f"    only-in-codex-tree : {only_a or '없음'}")

    lines.append("\n[4] 카탈로그(marketplace.json) 비대칭")
    cm, am = load_json(CLAUDE_CAT), load_json(CODEX_CAT)
    if cm and am:
        cnames = {x["name"] for x in cm.get("plugins", [])}
        anames = {x["name"] for x in am.get("plugins", [])}
        lines.append(f"    only-in-claude-catalog: {sorted(cnames - anames) or '없음'}")
        lines.append(f"    only-in-codex-catalog : {sorted(anames - cnames) or '없음'}")

    if not QUIET:
        print("\n".join(lines))
        print()

    if skew:
        print(f"FAIL: {len(skew)}개 플러그인 버전 skew — 양쪽 plugin.json 을 함께 bump 하라:")
        for p, cv, av in skew:
            print(f"  - {p}: claude={cv} / codex={av}")
        return 1
    print("OK: 버전 skew 없음." + (f" (SKILL 내용 차이 {len(skill_drift)}건은 검토 대상)" if skill_drift else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())

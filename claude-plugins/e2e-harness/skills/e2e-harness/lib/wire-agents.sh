#!/usr/bin/env bash
# Usage: wire-agents.sh --target <dir> [--run "<cmd>"] [--burnin "<cmd>"] [--doc <relpath>] [--title "..."]
#
# 대상 프로젝트의 AGENTS.md 에 "e2e-harness" 관리 블록을 insert-or-replace 한다(멱등).
# 발표 원칙: AGENTS.md 가 하네스의 1차 구성요소 — 미래 에이전트가 하네스를 자동 인지하고
# 코드 변경 후 검증을 돌리도록, 마커로 감싼 블록을 박는다. CLAUDE.md 가 AGENTS.md 를 가리키면
# Claude Code 도, AGENTS.md 를 읽는 Codex 도 동일하게 인지한다.
set -euo pipefail

TARGET=""; RUN="pnpm test:e2e"; BURNIN=""; DOC="e2e/README.md"; DIR="e2e/"; TITLE="E2E 검증 하네스 (자동 검증)"
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2;;
    --run)    RUN="$2"; shift 2;;
    --burnin) BURNIN="$2"; shift 2;;
    --doc)    DOC="$2"; shift 2;;
    --dir)    DIR="$2"; shift 2;;
    --title)  TITLE="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done
[ -n "$TARGET" ] || { echo "need --target" >&2; exit 2; }

AGENTS="$TARGET/AGENTS.md"
START="<!-- e2e-harness:start -->"
END="<!-- e2e-harness:end -->"

BLOCKFILE="$(mktemp)"
trap 'rm -f "$BLOCKFILE"' EXIT
{
  printf '%s\n' "$START"
  printf '## %s\n\n' "$TITLE"
  printf '이 프로젝트엔 자동 검증 하네스가 `%s` 에 있다. 코드 변경 후 **반드시** 검증한다.\n\n' "$DIR"
  printf -- '- 변경 후 검증: `%s`\n' "$RUN"
  [ -n "$BURNIN" ] && printf -- '- 머지 전 플래키 점검(번인): `%s`\n' "$BURNIN"
  printf -- '- 실패 시: trace 로 원인 진단 → 셀렉터/대기 조건 수정(고정 sleep 금지) → 재실행(자가수정 루프).\n'
  printf -- '- 새 크리티컬 플로우(실패 시 매출/데이터/신뢰가 깨지는 곳)만 사람과 합의해 추가.\n'
  printf -- '- 전체 워크플로·규약: `%s`\n' "$DOC"
  printf '%s\n' "$END"
} > "$BLOCKFILE"

mkdir -p "$TARGET"
if [ -f "$AGENTS" ] && grep -qF "$START" "$AGENTS"; then
  # 기존 블록을 마커 사이만 교체(멱등) — 나머지 내용 보존.
  awk -v s="$START" -v e="$END" -v bf="$BLOCKFILE" '
    $0==s { while ((getline line < bf) > 0) print line; close(bf); skip=1; next }
    $0==e { skip=0; next }
    !skip { print }
  ' "$AGENTS" > "$AGENTS.tmp" && mv "$AGENTS.tmp" "$AGENTS"
  echo "updated e2e-harness block in $AGENTS"
elif [ -f "$AGENTS" ]; then
  printf '\n' >> "$AGENTS"; cat "$BLOCKFILE" >> "$AGENTS"
  echo "appended e2e-harness block to $AGENTS"
else
  printf '# AGENTS.md\n\n' > "$AGENTS"; cat "$BLOCKFILE" >> "$AGENTS"
  echo "created $AGENTS with e2e-harness block"
fi

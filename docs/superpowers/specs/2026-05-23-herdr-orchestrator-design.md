# herdr-orchestrator skill — design spec

- date: 2026-05-23
- target marketplace: `gprecious-marketplace`
- new plugin: `herdr`
- new skill: `herdr-orchestrator`
- marketplace version bump: 1.1.0 → 1.2.0 (plugin 추가는 minor)

## 1. 목적

herdr (terminal-native agent multiplexer) 위에서 Claude Code 와 Codex 워커를 **병렬로 spawn → prompt 주입 → 완료 대기 → 결과 회수 → 자동 정리** 하는 경량 free-form orchestration skill.

호출자가 claude 든 codex 든 동일 절차로 동작 (호출자 = orchestrator, 양쪽 worker pane 별도 spawn). 협업 패턴(같은 task fan-out / task split / 한쪽만)은 호출자가 prompt 로 결정 — skill 은 primitive 만 제공.

## 2. 발동 조건

- 사용자가 "herdr 로 claude+codex 같이", "두 에이전트 병렬", "둘한테 동시에 시켜", "herdr orchestrator", "herdr pane spawn" 같은 의도를 표현할 때.
- **반드시** herdr 안에서 실행 중일 때 (`HERDR_ENV=1`). 아니면 skill 은 즉시 stop 하고 "herdr 안에서 호출하세요" 안내.
- 단일 파일 1회 편집 같은 단발 작업, 또는 claude/codex 한쪽만 호출하는 단순 작업은 발동 금지 — 다른 도구로 처리.

## 3. 인증 / 과금 정책 (불변)

- 모든 모델 호출은 다음 둘 중 하나의 OAuth/구독 인증을 통한다:
  - `claude --dangerously-skip-permissions` (Claude Code CLI, OAuth/구독)
  - `codex --dangerously-bypass-approvals-and-sandbox` (Codex CLI, OAuth/구독)
- skill body, spawned pane, 어떤 단계에서도 `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` 등 과금 API 키 사용 금지.
- anthropic / openai SDK 직접 import 또는 `api.anthropic.com` / `api.openai.com` 직접 HTTP 호출 금지.
- 이 정책을 어기는 PR/commit 은 거부 대상.

## 4. 위계 매핑 (default)

| herdr 개념 | 용도 |
|---|---|
| workspace | 한 task = 1 workspace. 새로 생성. 호출자 workspace 와 격리. |
| tab | worker pane 그룹. 각 tab 은 **최대 9 pane (3×3 grid)**. label `agents-1`, `agents-2`, ... |
| pane | 실제 worker (claude 또는 codex). N 개를 grid 슬롯에 채워 넣는다. |

호출자(orchestrator) 본인 pane 은 원래 workspace 에 그대로 남는다. worker workspace_id ≠ launcher workspace_id 를 매 send 직전 검증.

### 4.1 worker 수 → tab/pane 분배 규칙

- worker 수 **N** (호출자가 결정 — 1 ≤ N ≤ 임의).
- N ≤ 9: 단일 tab `agents-1` 안에 **3×3 grid** 로 배치. 사용하지 않는 슬롯은 생성하지 않음 (실제 pane 수 = N).
- N > 9: 매 9 개마다 새 tab (`agents-2`, `agents-3`, …) 생성. 남는 마지막 tab 도 동일 grid 패턴, 채울 만큼만 split.
- 호출자가 worker 의 역할 (claude/codex/임의 비율) 을 결정. skill 은 slot 순서대로 spawn — 협업 패턴(fan-out / split) 은 호출자 prompt 가 정의.

### 4.2 3×3 grid 빌드 순서 (한 tab 안)

herdr 는 `split --direction right|down` 두 방향만 지원하므로, **column 먼저, 그 다음 row** 로 재귀 split:

```
스텝 A — root pane 을 가로로 2번 split → col0 / col1 / col2 (가로 3분할)
스텝 B — 각 column 의 최상단 pane 을 세로로 2번 split → row0 / row1 / row2

결과 (한 tab):
  ┌─────────┬─────────┬─────────┐
  │ slot 0  │ slot 3  │ slot 6  │  ← row0
  ├─────────┼─────────┼─────────┤
  │ slot 1  │ slot 4  │ slot 7  │  ← row1
  ├─────────┼─────────┼─────────┤
  │ slot 2  │ slot 5  │ slot 8  │  ← row2
  └─────────┴─────────┴─────────┘
    col0       col1      col2

slot 인덱스 = col * 3 + row   (column-major)
```

worker 수가 9 미만이면 부족한 슬롯은 split 자체를 건너뛴다 (예: N=5 면 col0 전체 + col1 의 row0/row1 만 split).

### 4.3 변형 (skill body 가이드로만 안내)

- 단일 worker (claude only / codex only) — N=1, grid split 자체 skip.
- 한 prompt 를 모두에게 fan-out — 동일 `pane send-text` 를 모든 worker 에 반복.
- task 분할 — 호출자가 prompt 를 N 조각으로 쪼개 각 worker 에 송신.
- 역할 분담 — 짝수 slot 은 claude, 홀수 slot 은 codex (또는 호출자 임의 매핑).

## 5. 워크플로우

### 5.1 Preflight

```bash
[ "${HERDR_ENV:-0}" = "1" ] || { echo "not inside herdr — stop"; exit 1; }
command -v herdr >/dev/null || { echo "herdr CLI missing"; exit 1; }
command -v claude >/dev/null || { echo "claude CLI missing"; exit 1; }
command -v codex  >/dev/null || { echo "codex CLI missing"; exit 1; }
```

호출자 workspace_id 기록:

```bash
LAUNCHER_WS=$(herdr pane list | jq -r '.result.focused.workspace_id')
```

### 5.2 새 workspace 생성

```bash
SLUG="herdr-orc-$(date +%Y%m%d-%H%M%S)"
WS_JSON=$(herdr workspace create --cwd "$PWD" --label "$SLUG" --no-focus)
WS_ID=$(echo "$WS_JSON" | jq -r '.result.workspace.workspace_id')

[ "$WS_ID" = "$LAUNCHER_WS" ] && { echo "workspace isolation failed — abort"; exit 1; }
```

### 5.3 worker pane 일괄 spawn (3×3 grid + tab spillover)

호출자가 `WORKER_CMDS` 배열을 채워서 진입 (각 원소 = 그 slot 에서 실행할 CLI 명령). 예:

```bash
WORKER_CMDS=(
  "claude --dangerously-skip-permissions"
  "codex --dangerously-bypass-approvals-and-sandbox"
  "claude --dangerously-skip-permissions"
  # ... 최대 N 개
)
N=${#WORKER_CMDS[@]}
```

각 tab 당 최대 9개를 채우는 grid builder:

```bash
# build_grid_in_tab <tab_id> <count> → echo space-separated pane_ids in slot order
build_grid_in_tab() {
  local TAB_ID="$1" COUNT="$2"
  [ "$COUNT" -gt 9 ] && COUNT=9
  local root
  root=$(herdr pane list --tab "$TAB_ID" | jq -r '.result.panes[0].pane_id')

  # 1) 가로로 필요한 만큼 column split (총 column 수 = ceil(COUNT/3), 최대 3)
  local cols_needed=$(( (COUNT + 2) / 3 ))
  local -a col=( "$root" )
  for ((c=1; c<cols_needed; c++)); do
    col+=( "$(herdr pane split "${col[$((c-1))]}" --direction right --no-focus \
              | jq -r '.result.pane.pane_id')" )
  done

  # 2) 각 column 에 필요한 만큼 row split
  local -a slots=()
  local placed=0
  for ((c=0; c<cols_needed; c++)); do
    local rows_in_col=$(( COUNT - placed ))
    [ "$rows_in_col" -gt 3 ] && rows_in_col=3
    local r0="${col[$c]}"
    slots+=( "$r0" ); placed=$((placed+1))
    local prev="$r0"
    for ((r=1; r<rows_in_col; r++)); do
      prev=$(herdr pane split "$prev" --direction down --no-focus \
             | jq -r '.result.pane.pane_id')
      slots+=( "$prev" ); placed=$((placed+1))
    done
  done

  echo "${slots[@]}"
}
```

tab spillover + 모든 worker spawn:

```bash
declare -a TAB_IDS=()
declare -a PANES=()
remaining=$N
batch=0
while [ "$remaining" -gt 0 ]; do
  batch=$((batch+1))
  if [ "$batch" -eq 1 ]; then
    TID=$(herdr tab list --workspace "$WS_ID" | jq -r '.result.tabs[0].tab_id')
  else
    TID=$(herdr tab create --workspace "$WS_ID" --no-focus | jq -r '.result.tab.tab_id')
  fi
  herdr tab rename "$TID" "agents-${batch}"
  TAB_IDS+=( "$TID" )

  this_count=$(( remaining > 9 ? 9 : remaining ))
  read -r -a NEW_PANES <<< "$(build_grid_in_tab "$TID" "$this_count")"
  PANES+=( "${NEW_PANES[@]}" )
  remaining=$(( remaining - this_count ))
done

# 각 slot 에 worker CLI 실행
for ((i=0; i<N; i++)); do
  herdr pane run "${PANES[$i]}" "${WORKER_CMDS[$i]}"
done
```

### 5.4 prompt 주입 (격리 가드 후)

호출자가 `WORKER_PROMPTS` 배열을 채워서 진입 (slot 인덱스 정렬 = `WORKER_CMDS` 와 동일):

```bash
WORKER_PROMPTS=( "$PROMPT_FOR_SLOT_0" "$PROMPT_FOR_SLOT_1" ... )

send_prompt() {
  local PANE="$1" PROMPT="$2"
  local PANE_WS
  PANE_WS=$(herdr pane list | jq -r --arg p "$PANE" '.result.panes[] | select(.pane_id==$p) | .workspace_id')
  [ "$PANE_WS" = "$WS_ID" ] || { echo "pane $PANE workspace mismatch — abort"; return 1; }
  echo "send: from=orchestrator(ws:$LAUNCHER_WS) to=$PANE(ws:$PANE_WS)"
  herdr pane send-text "$PANE" "$PROMPT"
  herdr pane send-keys "$PANE" Enter
}

for ((i=0; i<N; i++)); do
  send_prompt "${PANES[$i]}" "${WORKER_PROMPTS[$i]}"
done
```

### 5.5 병렬 대기

모든 worker pane 에 `wait agent-status` 를 동시에 띄움:

```bash
declare -a WAIT_PIDS=()
declare -a WAIT_RCS=()
for ((i=0; i<N; i++)); do
  herdr wait agent-status "${PANES[$i]}" --status done --timeout 600000 &
  WAIT_PIDS+=( "$!" )
done
for ((i=0; i<N; i++)); do
  wait "${WAIT_PIDS[$i]}"
  WAIT_RCS+=( "$?" )
done
```

`WAIT_RCS[i] != 0` 인 slot 은 실패 (timeout/blocked) 로 기록. 하나라도 실패하면 5.7 cleanup 을 skip.

### 5.6 결과 회수

```bash
declare -a OUTPUTS=()
for ((i=0; i<N; i++)); do
  OUTPUTS+=( "$(herdr pane read "${PANES[$i]}" --source recent-unwrapped --lines 300)" )
done
```

orchestrator(호출자) 가 N 개 output 을 자연어로 사용자에게 정리 보고. (포맷·집계 방식은 호출자 재량 — skill 은 강제하지 않음.)

### 5.7 Cleanup (default 자동)

```bash
all_ok=1
for rc in "${WAIT_RCS[@]}"; do [ "$rc" = "0" ] || { all_ok=0; break; }; done

if [ "$all_ok" = "1" ] && [ "${KEEP_WS:-0}" != "1" ]; then
  herdr workspace close "$WS_ID"
  echo "cleanup: workspace $WS_ID closed (tabs ${TAB_IDS[*]} + ${#PANES[@]} panes 통째 정리)"
else
  echo "cleanup skipped — workspace $WS_ID kept for inspection"
  echo "  tabs: ${TAB_IDS[*]}"
  echo "  panes: ${PANES[*]}"
  echo "  rcs:   ${WAIT_RCS[*]}"
fi
```

- default: 모든 worker 정상 종료 시 `herdr workspace close $WS_ID` 한 번으로 worker pane / tab / workspace 통째 정리.
- 실패 시: workspace 유지 + 사용자에게 workspace_id, tab/pane 목록, 각 rc 값 안내 (디버깅).
- 사용자가 "유지해" / "결과 더 볼래" 명시한 경우 호출자가 `KEEP_WS=1` 로 skill body 진입 → close skip.

## 6. 파일 구조

```
gprecious-marketplace/
├── .claude-plugin/marketplace.json     # entry 추가 + version 1.2.0
├── README.md                            # plugin 표 동기화
└── claude-plugins/
    └── herdr/
        ├── .claude-plugin/plugin.json
        ├── README.md
        └── skills/
            └── herdr-orchestrator/
                └── SKILL.md
```

### 6.1 `claude-plugins/herdr/.claude-plugin/plugin.json`

```json
{
  "name": "herdr",
  "version": "0.1.0",
  "description": "herdr 위에서 Claude Code + Codex 워커를 병렬 spawn / prompt 주입 / 완료 대기 / 결과 회수 / 자동 정리 하는 경량 orchestrator.",
  "author": { "name": "gprecious" },
  "keywords": ["herdr", "orchestration", "multi-agent", "claude-code", "codex", "parallel"]
}
```

### 6.2 `marketplace.json` 신규 entry

```json
{
  "name": "herdr",
  "description": "herdr 위에서 Claude Code + Codex 워커 병렬 호출 + 결과 회수 + 자동 정리 orchestrator skill.",
  "source": "./claude-plugins/herdr",
  "category": "productivity"
}
```

## 7. 의존성 / Prerequisite

- **herdr CLI** PATH 에 있어야 함 (`HERDR_ENV=1` 자동 설정되는 환경).
- **claude CLI**, **codex CLI** 둘 다 OAuth/구독 로그인 완료된 상태.
- **공식 herdr skill** (gstack `herdr` skill, name=`herdr`) — SKILL 본문에서 "필요 시 Skill 도구로 `herdr` 호출해 워크스페이스/탭/페인 CLI 의 상세 사양 참고" 라고 안내. hard dependency 는 아님 (이 skill 자체에 충분한 CLI 사용 예시 포함).

## 8. 트리거 / non-트리거 가이드 (SKILL description 에 반영)

발동:
- "herdr 로 claude+codex 둘 다 시켜봐"
- "두 에이전트 병렬로 같은 task 던져봐"
- "herdr pane 새로 띄워서 codex 한테도 시켜"
- "herdr orchestrator"
- "한쪽은 plan, 다른쪽은 dev 로 나눠서 동시에"

발동 금지:
- "옆 pane 한테만 메시지 보내" — pane 단순 송수신은 herdr 공식 skill 또는 cmux-pane-chat.
- "한 줄 수정" — orchestration 오버헤드만 큼.
- "herdr 밖에서 병렬" — 이 skill 의 범위 밖.

## 9. 안전 / 격리 규칙 (요약)

1. **HERDR_ENV 가드**: skill 시작점에서 무조건 확인. 실패 시 stop.
2. **새 workspace 강제**: 호출자 workspace 안에 worker pane 만들기 금지. 매번 새 workspace.
3. **send 직전 workspace_id 검증**: pane 의 workspace_id 가 우리가 만든 `WS_ID` 와 일치할 때만 송신.
4. **타임아웃 + 실패 보존**: 실패 시 workspace 닫지 않음 — 디버깅 가능하도록.
5. **인증 정책 불변**: API 키 사용 금지. OAuth CLI 만.

## 10. 비기능 / 미구현 (YAGNI)

다음은 이 v0.1.0 범위 **밖**:

- manifest.json / 영속 상태 (cmux-orchestrator 의 복잡한 manifest 구조 미도입).
- TDD 파이프라인 (RED → GREEN), Figma 일치도 검증 등 cmux-orchestrator 의 풀 파이프라인.
- 결과 자동 비교/diff 알고리즘 — 호출자가 자연어로 처리.
- resume 모드 — workspace 닫히면 끝.
- bats 테스트 — v0.1.0 은 SKILL.md 중심, 스크립트화는 v0.2 이후.

필요해지면 별도 spec → 후속 버전.

## 11. 작업 순서 (구현 계획)

1. `claude-plugins/herdr/` 디렉토리 + `plugin.json` 작성
2. `claude-plugins/herdr/skills/herdr-orchestrator/SKILL.md` 작성 (위 워크플로우 그대로)
3. `claude-plugins/herdr/README.md` 작성 (사용 예 + prerequisite)
4. `.claude-plugin/marketplace.json` entry 추가 + version 1.1.0 → 1.2.0
5. 루트 `README.md` plugin 표 동기화
6. commit + push

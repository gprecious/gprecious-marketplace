---
name: herdr-orchestrator
description: |
  herdr (terminal-native agent multiplexer) 위에서 Claude Code 와 Codex 워커를
  병렬 spawn → prompt 주입 → 완료 대기 → 결과 회수 → 자동 정리 하는 경량
  orchestrator. 한 tab 당 최대 9 pane (3x3 grid), 9개 초과 시 새 tab 분기.
  사용자가 "herdr 로 claude+codex 같이", "두 에이전트 병렬", "둘한테 동시에 시켜",
  "herdr orchestrator", "herdr pane 새로 띄워서 codex 한테도", "여러 worker 병렬"
  같은 의도를 표현할 때 발동. herdr 안에서만 (HERDR_ENV=1) 동작.
  Claude Code / Codex 어느 쪽에서 호출해도 호출자 = orchestrator, worker pane 은
  별도 spawn 하는 동일 절차.
---

# herdr-orchestrator

herdr 위에서 다수 worker (`claude`, `codex`) 를 병렬 호출하기 위한 free-form
orchestrator. 협업 패턴 (fan-out / split / 역할 분담) 은 호출자가 prompt 로
결정 — 이 skill 은 spawn·대기·회수·정리 primitive 만 제공한다.

## 발동 / 비발동

발동:
- "herdr 로 claude+codex 둘 다 시켜봐"
- "두 에이전트 병렬로 같은 task 던져봐"
- "herdr pane 새로 띄워서 codex 한테도 시켜"
- "한쪽은 plan, 다른쪽은 dev 로 나눠서 동시에"
- worker 3개 이상 (예: claude 2 + codex 1, codex 9개 fan-out 등)

비발동:
- 단일 worker 만 필요 — `herdr` 공식 skill 직접 호출.
- 단순 pane 송수신 — 다른 가벼운 skill.
- herdr 밖 환경 — 이 skill 범위 밖.

## 인증 / 과금 정책 (불변)

- 모든 모델 호출은 다음 둘 중 하나의 **OAuth/구독** 인증을 통한다:
  - `claude --dangerously-skip-permissions` (Claude Code CLI)
  - `codex --dangerously-bypass-approvals-and-sandbox` (Codex CLI)
- skill body, spawned pane, 어떤 단계에서도 `ANTHROPIC_API_KEY` /
  `OPENAI_API_KEY` 등 과금 API 키 사용 금지.
- anthropic / openai SDK 직접 import, `api.anthropic.com` / `api.openai.com`
  직접 HTTP 호출 금지.
- 이 정책을 어기는 PR/commit 은 거부 대상.

## 워커 실행 모드 (불변): 인터랙티브 TUI only

worker pane 에는 **항상 인터랙티브 TUI 세션**을 띄운다. prompt 는 CLI 인자로 붙이지
않고, 세션이 시작된 뒤 `send-text` / `send-keys` 로 주입한다. 그래야 사용자가 pane
에서 에이전트가 실시간으로 일하는 모습을 직접 볼 수 있다.

올바름 (인터랙티브 — 세션 유지, 사용자 관찰 가능):
- `claude --dangerously-skip-permissions`  → 이후 `send-text` 로 prompt 주입
- `codex --dangerously-bypass-approvals-and-sandbox`  → 이후 `send-text` 로 prompt 주입

**금지** (headless one-shot — 사용자 눈에 안 보이고 즉시 종료해 백그라운드처럼 느껴짐):
- `claude -p "..."` / `claude --print "..."`
- `codex exec "..."`
- prompt 를 CLI 인자로 직접 붙여 한 번에 실행하는 모든 형태

즉 `pane run` 으로 띄우는 명령에는 **prompt 가 절대 포함되지 않는다**. 명령은 TUI 를
띄우기만 하고, prompt 는 반드시 별도 prompt 주입 단계(4)에서 넣는다.

## 위계 매핑

| herdr 개념 | 용도 |
|---|---|
| workspace | 한 task = 1 workspace. 새로 생성. 호출자 workspace 와 격리. |
| tab | worker pane 그룹. 각 tab 최대 9 pane (3×3). label `agents-1`, `agents-2`, ... |
| pane | 실제 worker (claude 또는 codex). slot 순서로 채움. |

호출자(orchestrator) 본인 pane 은 원래 workspace 에 그대로 둔다. worker
workspace_id ≠ launcher workspace_id 를 매 send 직전 검증.

### 3×3 grid 배치

```
  ┌─────────┬─────────┬─────────┐
  │ slot 0  │ slot 3  │ slot 6  │  ← row 0
  ├─────────┼─────────┼─────────┤
  │ slot 1  │ slot 4  │ slot 7  │  ← row 1
  ├─────────┼─────────┼─────────┤
  │ slot 2  │ slot 5  │ slot 8  │  ← row 2
  └─────────┴─────────┴─────────┘
    col 0     col 1     col 2

slot index = col * 3 + row   (column-major)
```

worker 수 N 분배:
- `N ≤ 9` → 단일 tab `agents-1`, 필요한 슬롯만 split.
- `N > 9` → 매 9개마다 새 tab (`agents-2`, …).
- 부족한 슬롯은 split 자체 skip (예: N=5 → col0 전체 + col1 의 row0/row1 만).

## Prerequisite

- `HERDR_ENV=1` (herdr 안에서 실행 중).
- `herdr` CLI PATH 에 있음.
- `claude`, `codex` CLI 둘 다 OAuth/구독 로그인 완료.
- (선택) 공식 `herdr` skill 도 활성화되어 있으면 워크스페이스/탭/페인 CLI 상세
  사양을 추가 참조 가능. 없어도 본 SKILL 의 레시피로 충분.

## 워크플로우

### 0. Preflight (필수)

```bash
[ "${HERDR_ENV:-0}" = "1" ] || { echo "not inside herdr — stop"; exit 1; }
command -v herdr  >/dev/null || { echo "herdr CLI missing";  exit 1; }
command -v claude >/dev/null || { echo "claude CLI missing"; exit 1; }
command -v codex  >/dev/null || { echo "codex CLI missing";  exit 1; }

LAUNCHER_WS=$(herdr pane list | jq -r '.result.focused.workspace_id')
```

### 1. 호출자 결정 변수

호출자(Claude Code 또는 Codex)는 skill body 진입 전에 두 배열을 정의한다.

```bash
# WORKER_CMDS = TUI 를 띄우는 명령만. prompt 절대 포함 금지 (-p / exec 금지 — 위 불변 규칙).
WORKER_CMDS=(
  "claude --dangerously-skip-permissions"
  "codex --dangerously-bypass-approvals-and-sandbox"
  # ... 최대 N 개. 동일 CLI 반복 OK (예: claude x4 + codex x2).
)
WORKER_PROMPTS=(
  "$PROMPT_FOR_SLOT_0"
  "$PROMPT_FOR_SLOT_1"
  # ... slot 인덱스 정렬 = WORKER_CMDS 와 동일
)
N=${#WORKER_CMDS[@]}
[ "$N" -eq "${#WORKER_PROMPTS[@]}" ] || { echo "len(WORKER_CMDS) != len(WORKER_PROMPTS)"; exit 1; }
[ "$N" -ge 1 ] || { echo "N must be >= 1"; exit 1; }

# 옵션
: "${KEEP_WS:=0}"          # 1 이면 close 확인 절차 생략하고 항상 workspace 유지
: "${TIMEOUT_MS:=600000}"  # worker 당 대기 타임아웃 (ms)
```

협업 패턴 예시 (호출자가 prompt 단계에서 결정):
- **fan-out** (같은 task) → `WORKER_PROMPTS` 모두 동일 문자열.
- **split** → 호출자가 task 를 N 조각으로 쪼개 각 slot 에 다른 prompt.
- **역할 분담** → slot 별로 claude/codex 비율 + prompt 를 호출자가 매핑.

### 2. 새 workspace 생성 (격리)

```bash
SLUG="herdr-orc-$(date +%Y%m%d-%H%M%S)"
WS_ID=$(herdr workspace create --cwd "$PWD" --label "$SLUG" --no-focus \
        | jq -r '.result.workspace.workspace_id')

[ "$WS_ID" = "$LAUNCHER_WS" ] && { echo "workspace isolation failed — abort"; exit 1; }
```

### 3. worker pane spawn (3×3 grid + tab spillover)

```bash
# 한 tab 안에 COUNT (1~9) 개의 pane 을 column-major 로 split.
# echo space-separated pane_ids in slot order.
build_grid_in_tab() {
  local TAB_ID="$1" COUNT="$2"
  [ "$COUNT" -gt 9 ] && COUNT=9

  local root
  root=$(herdr pane list --tab "$TAB_ID" | jq -r '.result.panes[0].pane_id')

  # (A) 가로로 필요한 만큼 column split — col 수 = ceil(COUNT/3)
  local cols_needed=$(( (COUNT + 2) / 3 ))
  local -a col=( "$root" )
  for ((c=1; c<cols_needed; c++)); do
    col+=( "$(herdr pane split "${col[$((c-1))]}" --direction right --no-focus \
              | jq -r '.result.pane.pane_id')" )
  done

  # (B) 각 column 의 최상단 pane 을 세로로 split
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

# tab spillover + 각 slot 에 worker CLI 실행
declare -a TAB_IDS=()
declare -a PANES=()
remaining=$N
batch=0
while [ "$remaining" -gt 0 ]; do
  batch=$((batch+1))
  if [ "$batch" -eq 1 ]; then
    TID=$(herdr tab list --workspace "$WS_ID" | jq -r '.result.tabs[0].tab_id')
  else
    TID=$(herdr tab create --workspace "$WS_ID" --no-focus \
          | jq -r '.result.tab.tab_id')
  fi
  herdr tab rename "$TID" "agents-${batch}"
  TAB_IDS+=( "$TID" )

  this_count=$(( remaining > 9 ? 9 : remaining ))
  read -r -a NEW_PANES <<< "$(build_grid_in_tab "$TID" "$this_count")"
  PANES+=( "${NEW_PANES[@]}" )
  remaining=$(( remaining - this_count ))
done

# 각 slot 에 worker TUI 띄우기 (prompt 없이 — 인터랙티브 세션만 시작)
for ((i=0; i<N; i++)); do
  herdr pane run "${PANES[$i]}" "${WORKER_CMDS[$i]}"
done
```

`WORKER_CMDS` 에는 prompt 가 없다 (불변 규칙). `claude -p` / `codex exec` 같은
headless one-shot 으로 띄우지 말 것 — 사용자가 못 보고 즉시 끝난다.

CLI 가 prompt 입력 가능 상태가 되도록 잠깐 대기 (claude / codex 시작 대기). 안전한
방법은 각 worker pane 에서 "ready" 신호를 `wait output` 으로 받는 것:

```bash
for ((i=0; i<N; i++)); do
  # claude/codex 둘 다 ">" 또는 prompt 마커가 뜰 때까지 대기 (단순 휴리스틱)
  herdr wait output "${PANES[$i]}" --match ">" --timeout 30000 || true
done
```

### 3.5 worker workspace 보이기 (focus — 필수)

worker TUI 가 다 떴으면 사용자가 실시간으로 볼 수 있도록 worker workspace 로 focus
를 전환한다. orchestrator 본인 pane 은 launcher workspace 에서 백그라운드로 계속
동작하므로 focus 를 옮겨도 조율은 멈추지 않는다.

```bash
herdr workspace focus "$WS_ID"
```

### 4. prompt 주입 (격리 가드)

```bash
send_prompt() {
  local PANE="$1" PROMPT="$2"
  local PANE_WS
  PANE_WS=$(herdr pane list \
            | jq -r --arg p "$PANE" '.result.panes[] | select(.pane_id==$p) | .workspace_id')
  [ "$PANE_WS" = "$WS_ID" ] || { echo "pane $PANE workspace mismatch — abort"; return 1; }
  echo "send: from=orchestrator(ws:$LAUNCHER_WS) to=$PANE(ws:$PANE_WS)"
  herdr pane send-text "$PANE" "$PROMPT"
  herdr pane send-keys "$PANE" Enter
}

for ((i=0; i<N; i++)); do
  send_prompt "${PANES[$i]}" "${WORKER_PROMPTS[$i]}" || exit 1
done
```

### 5. 병렬 대기

```bash
declare -a WAIT_PIDS=()
declare -a WAIT_RCS=()

for ((i=0; i<N; i++)); do
  herdr wait agent-status "${PANES[$i]}" --status done --timeout "$TIMEOUT_MS" &
  WAIT_PIDS+=( "$!" )
done

for ((i=0; i<N; i++)); do
  wait "${WAIT_PIDS[$i]}"
  WAIT_RCS+=( "$?" )
done
```

`WAIT_RCS[i] != 0` 인 slot 은 실패 (timeout / blocked).

### 6. 결과 회수

```bash
declare -a OUTPUTS=()
for ((i=0; i<N; i++)); do
  OUTPUTS+=( "$(herdr pane read "${PANES[$i]}" \
                --source recent-unwrapped --lines 300)" )
done

# 결과를 보고하기 전에 orchestrator pane 으로 focus 복귀 — 사용자가 요약 보고 +
# close 확인 질문을 자기 화면(launcher workspace)에서 보게 한다.
herdr workspace focus "$LAUNCHER_WS"
```

orchestrator (호출자) 가 `${OUTPUTS[@]}` 를 자연어로 사용자에게 정리 보고. 집계
포맷은 호출자 재량 — 비교 / 합치기 / 요약 자유.

### 7. Cleanup (사용자 확인 후 close)

worker workspace 는 **자동으로 닫지 않는다**. 사용자가 직접 worker pane 의 최종
상태를 확인할 수 있어야 하므로, 성공해도 바로 close 하지 않는다.

절차:

1. orchestrator 가 `${OUTPUTS[@]}` 를 자연어로 사용자에게 보고한다.
2. 실패한 slot 이 있으면 (`WAIT_RCS` 에 비-0) tabs / panes / rcs 를 안내하고 보존.
3. 사용자에게 worker workspace 를 닫아도 되는지 확인한다 (`WS_ID` 안내).
4. 사용자가 확인하면 **그때** close:

```bash
all_ok=1
for rc in "${WAIT_RCS[@]}"; do
  [ "$rc" = "0" ] || { all_ok=0; break; }
done

if [ "$all_ok" != "1" ]; then
  echo "일부 worker 실패 — workspace $WS_ID 보존 (확인용)"
  echo "  tabs:  ${TAB_IDS[*]}"
  echo "  panes: ${PANES[*]}"
  echo "  rcs:   ${WAIT_RCS[*]}"
fi

# 아래 close 는 사용자가 "닫아도 된다" 고 확인한 뒤에만 실행한다.
# (orchestrator 가 다음 턴에서 사용자 응답을 받고 호출)
#   herdr workspace close "$WS_ID"
#   echo "cleanup: workspace $WS_ID closed (tabs ${TAB_IDS[*]} + ${#PANES[@]} panes 통째 정리)"
```

- default: 성공/실패와 무관하게 workspace 를 유지하고 사용자 확인을 기다린 뒤 close.
- `KEEP_WS=1`: 확인 절차도 생략하고 항상 유지 (사용자가 수동 정리).

## 호출자별 진입점

### Claude Code 호출자

이 SKILL.md 자체가 발동. 위 워크플로우를 그대로 따라 bash 스니펫을 단계별 실행.
호출자는 `WORKER_CMDS` / `WORKER_PROMPTS` 를 본인 컨텍스트 기반으로 구성하고,
최종 `${OUTPUTS[@]}` 을 자연어로 사용자에게 보고.

### Codex 호출자

Codex CLI 는 SKILL.md 자동 발동 메커니즘이 없으므로, 사용자가 다음 중 하나로
진입:

1. 사용자 prompt 에 "이 파일 따라줘:
   `claude-plugins/herdr/skills/herdr-orchestrator/SKILL.md`" 명시.
2. 또는 호출자 codex 세션에서 `cat claude-plugins/herdr/skills/herdr-orchestrator/SKILL.md`
   를 먼저 읽고 동일 절차 수행.

Codex 호출자도 본인은 orchestrator 로 남고, worker pane (claude/codex 어느 쪽이든)
은 새 workspace 에 별도 spawn 한다.

## 안전 / 격리 규칙 (요약)

1. **HERDR_ENV 가드** — skill 시작점에서 무조건 확인. 실패 시 stop.
2. **새 workspace 강제** — 호출자 workspace 안에 worker pane 만들기 금지. 매번
   새 workspace.
3. **send 직전 workspace_id 검증** — pane 의 workspace_id 가 `WS_ID` 와 일치할
   때만 송신.
4. **타임아웃 + 확인 후 정리** — 성공/실패 무관하게 자동 close 금지. 결과 보고 후
   사용자 확인을 받고 close. 실패 시 tabs / panes / rcs 안내.
5. **인증 정책 불변** — API 키 사용 금지. OAuth CLI 만.
6. **인터랙티브 TUI only** — worker 는 항상 TUI 로 띄우고 prompt 는 `send-text` 로
   주입. `claude -p` / `codex exec` 등 headless one-shot 금지. spawn 후 worker
   workspace 로 focus 전환해 사용자가 실시간 관찰 가능하게 함.

## 비기능 / 미구현 (v0.1.0 YAGNI)

다음은 본 버전 범위 밖. 필요해지면 별도 spec → 후속 버전.

- manifest.json / 영속 상태.
- resume 모드 (workspace 닫히면 끝).
- 결과 자동 비교/diff/투표 알고리즘 — 호출자 자연어 처리.
- TDD 파이프라인 (RED/GREEN), 디자인 일치도 검증 등 풀 파이프라인.
- bats 테스트 — 본 버전은 SKILL.md 중심. 스크립트화는 v0.2 이후.

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
  호출자 workspace 안의 새 tab 에 별도 spawn 하는 동일 절차 (workspace 는 새로
  만들지 않는다).
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

- `claude --dangerously-skip-permissions` → 이후 `send-text` 로 prompt 주입
- `codex --dangerously-bypass-approvals-and-sandbox` → 이후 `send-text` 로 prompt 주입

**금지** (headless one-shot — 사용자 눈에 안 보이고 즉시 종료해 백그라운드처럼 느껴짐):

- `claude -p "..."` / `claude --print "..."`
- `codex exec "..."`
- prompt 를 CLI 인자로 직접 붙여 한 번에 실행하는 모든 형태

즉 `pane run` 으로 띄우는 명령에는 **prompt 가 절대 포함되지 않는다**. 명령은 TUI 를
띄우기만 하고, prompt 는 반드시 별도 prompt 주입 단계(4)에서 넣는다.

## 위계 매핑

| herdr 개념 | 용도                                                                          |
| ---------- | ----------------------------------------------------------------------------- |
| workspace  | 호출자(orchestrator) workspace 를 **그대로 공유**. 새로 만들지 않는다.        |
| tab        | worker pane 그룹. 한 task = 새 tab(들). 각 tab 최대 9 pane (3×3). label `SLUG-1`, `SLUG-2`, ... 호출자 tab 과 격리. |
| pane       | 실제 worker (claude 또는 codex). slot 순서로 채움.                            |

호출자(orchestrator) 본인 pane 이 있는 tab(`LAUNCHER_TAB`)은 그대로 두고 절대
건드리지 않는다. worker tab_id ≠ `LAUNCHER_TAB` 를 매 send·close 직전 검증.

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

- `N ≤ 9` → 단일 worker tab `SLUG-1`, 필요한 슬롯만 split.
- `N > 9` → 매 9개마다 새 worker tab (`SLUG-2`, …).
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

# focused pane = orchestrator 본인. workspace_id 와 tab_id 를 둘 다 기록.
# (herdr 버전에 따라 .result.focused 가 null 일 수 있어 panes[] fallback 사용)
LAUNCHER_WS=$(herdr pane list | jq -r '.result.focused.workspace_id // (.result.panes[] | select(.focused==true) | .workspace_id)')
LAUNCHER_TAB=$(herdr pane list | jq -r '.result.focused.tab_id // (.result.panes[] | select(.focused==true) | .tab_id)')
[ -n "$LAUNCHER_WS"  ] && [ "$LAUNCHER_WS"  != "null" ] || { echo "cannot resolve launcher workspace — stop"; exit 1; }
[ -n "$LAUNCHER_TAB" ] && [ "$LAUNCHER_TAB" != "null" ] || { echo "cannot resolve launcher tab — stop"; exit 1; }
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
# (v0.3) WORKER_MODES = slot 별 초기 effort/모드 (선택). WORKER_CMDS 와 index 정렬.
#   plain(기본) | ultracode | max | xhigh | high | medium | low
WORKER_MODES=(
  # "ultracode"   # 예: slot 0 은 깊은 fan-out → ultracode 로 시작
  # "plain"       # 예: slot 1 은 평소 effort
)
N=${#WORKER_CMDS[@]}
[ "$N" -eq "${#WORKER_PROMPTS[@]}" ] || { echo "len(WORKER_CMDS) != len(WORKER_PROMPTS)"; exit 1; }
[ "$N" -ge 1 ] || { echo "N must be >= 1"; exit 1; }

# (v0.3) WORKER_MODES 길이 보정 — 미지정 slot 은 plain.
declare -a WORKER_MODES=("${WORKER_MODES[@]}")
for ((i=0; i<N; i++)); do : "${WORKER_MODES[$i]:=plain}"; done

# 옵션
: "${KEEP_TABS:=0}"        # 1 이면 close 확인 절차 생략하고 worker tab 항상 유지
: "${TIMEOUT_MS:=600000}"  # worker 당 대기 타임아웃 (ms)
```

협업 패턴 예시 (호출자가 prompt 단계에서 결정):

- **fan-out** (같은 task) → `WORKER_PROMPTS` 모두 동일 문자열.
- **split** → 호출자가 task 를 N 조각으로 쪼개 각 slot 에 다른 prompt.
- **역할 분담** → slot 별로 claude/codex 비율 + prompt 를 호출자가 매핑.

(v0.3) **effort 계층 규약** — `ultracode`/`xhigh` 워커에 prompt 를 줄 때 다음 한 줄을
접미로 포함해 비용을 계층화한다: _"workflow 를 쓸 때 subagent 는 low effort 로 생성해
비용을 절감하고, 너(orchestrator pane)만 xhigh 로 판단해라."_ — pane(세션) effort 는
herdr 가 `WORKER_MODES`/`toggle_mode` 로 제어하지만, 워커가 띄우는 workflow subagent 의
effort 는 워커가 작성하는 스크립트가 정하므로 prompt 규약으로 강제.

### 2. workspace 결정 (호출자 workspace 공유 — 새로 만들지 않음)

worker 는 호출자와 **같은 workspace** 에 둔다 (새 workspace 를 만들면 workspace 가
계속 쌓여 불편). 격리는 workspace 가 아니라 **tab** 단위로 한다 — 3단계에서 worker 마다
새 tab 을 만들고 `LAUNCHER_TAB`(orchestrator 본인 tab)은 건드리지 않는다. cwd 는 기존과
동일하게 `$PWD` 를 따른다.

```bash
WS_ID="$LAUNCHER_WS"                       # 새 workspace 생성 없음 — 호출자 workspace 재사용
SLUG="herdr-orc-$(date +%Y%m%d-%H%M%S)"   # worker tab label 식별자 (한 workspace 에 여러 task tab 공존 가능)
```

> 파일시스템까지 격리하려면(같은 repo 동시 쓰기 충돌 방지) 이 skill 범위 밖의
> `herdr worktree` / git worktree 를 호출자가 별도로 준비한다. workspace 분리는
> herdr UI 상의 분리였을 뿐 cwd 격리가 아니었다 (worker cwd 는 늘 `$PWD`).

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
  # 항상 새 tab 을 만든다. launcher workspace 의 기존 tab(특히 LAUNCHER_TAB)은
  # orchestrator 본인 pane 이 있을 수 있으므로 절대 재사용·split 하지 않는다.
  TID=$(herdr tab create --workspace "$WS_ID" --cwd "$PWD" --no-focus \
        | jq -r '.result.tab.tab_id')
  [ -n "$TID" ] && [ "$TID" != "null" ] || { echo "tab create 실패 — abort"; exit 1; }
  [ "$TID" = "$LAUNCHER_TAB" ] && { echo "새 tab 이 LAUNCHER_TAB 과 충돌 — abort"; exit 1; }
  herdr tab rename "$TID" "${SLUG}-${batch}"
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

### 3.5 worker tab 보이기 (focus — 필수)

worker TUI 가 다 떴으면 사용자가 실시간으로 볼 수 있도록 worker 의 첫 tab 으로 focus
를 전환한다. orchestrator 본인 pane(`LAUNCHER_TAB`)은 같은 workspace 의 다른 tab 에서
백그라운드로 계속 동작하므로 focus 를 옮겨도 조율은 멈추지 않는다.

```bash
herdr tab focus "${TAB_IDS[0]}"
```

### 4. prompt 주입 (격리 가드)

```bash
# worker tab 화이트리스트 membership 검사 (LAUNCHER_TAB 은 절대 매칭 안 됨).
is_worker_tab() {
  local T="$1"
  [ "$T" = "$LAUNCHER_TAB" ] && return 1
  local wt
  for wt in "${TAB_IDS[@]}"; do [ "$wt" = "$T" ] && return 0; done
  return 1
}

send_prompt() {
  local PANE="$1" PROMPT="$2"
  local PANE_TAB
  PANE_TAB=$(herdr pane list \
             | jq -r --arg p "$PANE" '.result.panes[] | select(.pane_id==$p) | .tab_id')
  is_worker_tab "$PANE_TAB" || { echo "pane $PANE tab($PANE_TAB) is not a worker tab — abort"; return 1; }
  echo "send: from=orchestrator(tab:$LAUNCHER_TAB) to=$PANE(tab:$PANE_TAB)"
  herdr pane send-text "$PANE" "$PROMPT"
  herdr pane send-keys "$PANE" Enter
}

for ((i=0; i<N; i++)); do
  # (v0.3) plain 이 아니면 prompt 주입 전에 모드 먼저 전환 (cache 보존 escalation).
  [ "${WORKER_MODES[$i]}" != "plain" ] && toggle_mode "$i" "${WORKER_MODES[$i]}"
  send_prompt "${PANES[$i]}" "${WORKER_PROMPTS[$i]}" || exit 1
done
```

### 4.5 toggle_mode — 세션 중간 effort/모드 전환 (v0.3)

워커 pane 의 effort/모드를 세션 중간에 **싸게** 전환하는 primitive. Opus 4.8 의
mid-conversation system message 덕에, Claude Code 가 `/effort` 슬래시를 messages 배열
**꼬리**에 system 엔트리로 반영 → 앞선 긴 컨텍스트의 prompt cache 가 보존된다
(top-level `system` 수정 시 발생하는 전체 재처리를 회피). 즉 "평소엔 가볍게, 깊은
구간에서만 ultracode" 운영이 경제적이다.

```bash
# 사용: toggle_mode <slot_index> <mode>
#   mode ∈ ultracode | max | xhigh | high | medium | low
# 전제:
#   - 해당 slot 이 claude 워커일 것 (codex 는 /effort 슬래시 없음 → skip).
#   - 호출 시점에 그 pane 이 입력 프롬프트 대기 상태일 것 (생성 중이면 슬래시가
#     큐잉/무시될 수 있음). spawn 직후(prompt 주입 전) 또는 한 task 완료 후가 안전.
toggle_mode() {
  local I="$1" MODE="$2"
  local PANE="${PANES[$I]}" CMD="${WORKER_CMDS[$I]}"

  # 1) codex 워커는 /effort 슬래시가 없다 — skip (codex 는 spawn 시 모델 플래그로 제어).
  case "$CMD" in
    claude*) : ;;
    *) echo "toggle_mode: slot $I 는 claude 가 아님 ($CMD) — skip"; return 0 ;;
  esac

  # 2) 모드 화이트리스트 검증.
  case "$MODE" in
    ultracode|max|xhigh|high|medium|low) : ;;
    *) echo "toggle_mode: 알 수 없는 mode '$MODE'"; return 1 ;;
  esac

  # 3) 격리 가드 — pane 이 worker tab 에 속할 때만 송신 (send_prompt 와 동일 규칙).
  local PANE_TAB
  PANE_TAB=$(herdr pane list \
             | jq -r --arg p "$PANE" '.result.panes[] | select(.pane_id==$p) | .tab_id')
  is_worker_tab "$PANE_TAB" || { echo "toggle_mode: pane $PANE tab($PANE_TAB) is not a worker tab — abort"; return 1; }

  # 4) /effort 슬래시 주입. 슬래시는 모델 turn 을 소비하지 않고 즉시 처리되며,
  #    Claude Code 가 이를 mid-conversation system message 로 반영 → cache 보존.
  echo "toggle_mode: slot $I (tab:$PANE_TAB) → /effort $MODE"
  herdr pane send-text "$PANE" "/effort $MODE"
  herdr pane send-keys "$PANE" Enter

  # 5) 적용 확인 — effort 라벨이 TUI 에 뜰 때까지 짧게 대기 (best-effort, 실패해도 계속).
  herdr wait output "$PANE" --match "$MODE" --timeout 8000 \
    || echo "toggle_mode: slot $I effort 라벨 확인 실패 (계속 진행)"
}
```

**단계별 재-escalation (선택, 고급)** — 한 워커를 "가볍게 1차 → 깊게 2차" 로 운영.
1차 완료를 기다린 뒤 ultracode 로 올리고 후속 prompt 를 던진다. cache 가 보존되므로
1차 컨텍스트를 그대로 들고 깊이만 키운다:

```bash
# slot 0 을 가볍게 1차 실행했다고 가정 (WORKER_MODES[0]=plain)
herdr wait agent-status "${PANES[0]}" --status done --timeout "$TIMEOUT_MS"

# 2차: ultracode 로 올리고 심화 prompt 주입 (de-escalation 은 toggle_mode 0 high)
toggle_mode 0 ultracode
send_prompt "${PANES[0]}" "1차 결과를 바탕으로, workflow 로 전 구간을 교차검증해줘."
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

# 결과를 보고하기 전에 orchestrator tab 으로 focus 복귀 — 사용자가 요약 보고 +
# close 확인 질문을 자기 화면(LAUNCHER_TAB)에서 보게 한다.
herdr tab focus "$LAUNCHER_TAB"
```

orchestrator (호출자) 가 `${OUTPUTS[@]}` 를 자연어로 사용자에게 정리 보고. 집계
포맷은 호출자 재량 — 비교 / 합치기 / 요약 자유.

### 7. Cleanup (사용자 확인 후 worker tab 만 close)

worker tab 은 **자동으로 닫지 않는다**. 사용자가 직접 worker pane 의 최종 상태를
확인할 수 있어야 하므로, 성공해도 바로 close 하지 않는다. **호출자 workspace 와
`LAUNCHER_TAB` 은 절대 닫지 않는다** — orchestrator 본인이 거기 있다. 정리 대상은 이
task 가 만든 worker tab(`TAB_IDS`) 뿐이다.

절차:

1. orchestrator 가 `${OUTPUTS[@]}` 를 자연어로 사용자에게 보고한다.
2. 실패한 slot 이 있으면 (`WAIT_RCS` 에 비-0) tabs / panes / rcs 를 안내하고 보존.
3. 사용자에게 worker tab 을 닫아도 되는지 확인한다 (`TAB_IDS` 안내).
4. 사용자가 확인하면 **그때** worker tab 만 close:

```bash
all_ok=1
for rc in "${WAIT_RCS[@]}"; do
  [ "$rc" = "0" ] || { all_ok=0; break; }
done

if [ "$all_ok" != "1" ]; then
  echo "일부 worker 실패 — worker tab 보존 (확인용)"
  echo "  tabs:  ${TAB_IDS[*]}"
  echo "  panes: ${PANES[*]}"
  echo "  rcs:   ${WAIT_RCS[*]}"
fi

# 아래 close 는 사용자가 "닫아도 된다" 고 확인한 뒤에만 실행한다.
# (orchestrator 가 다음 턴에서 사용자 응답을 받고 호출)
# 절대 LAUNCHER_TAB / workspace 는 close 하지 않는다 — worker tab 만.
#   for t in "${TAB_IDS[@]}"; do
#     [ "$t" = "$LAUNCHER_TAB" ] && { echo "guard: refuse to close LAUNCHER_TAB"; continue; }
#     herdr tab close "$t"
#   done
#   echo "cleanup: worker tabs ${TAB_IDS[*]} closed (${#PANES[@]} panes 통째 정리). workspace/LAUNCHER_TAB 보존."
```

- default: 성공/실패와 무관하게 worker tab 을 유지하고 사용자 확인을 기다린 뒤 close.
- `KEEP_TABS=1`: 확인 절차도 생략하고 항상 유지 (사용자가 수동 정리).

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
은 호출자 workspace 안의 새 tab 에 별도 spawn 한다.

## 안전 / 격리 규칙 (요약)

1. **HERDR_ENV 가드** — skill 시작점에서 무조건 확인. 실패 시 stop.
2. **새 tab 강제 + LAUNCHER_TAB 격리** — 호출자 workspace 를 공유하되, worker 는
   매번 **새 tab** 에 만든다. `LAUNCHER_TAB`(orchestrator 본인 pane) 및 기존 tab 은
   재사용·split 금지. 새 workspace 는 만들지 않는다 (workspace 누적 방지).
3. **send 직전 worker-tab 검증** — pane 의 tab_id 가 worker `TAB_IDS` 에 속하고
   `LAUNCHER_TAB` 이 아닐 때만 송신 (`is_worker_tab`).
4. **타임아웃 + 확인 후 정리** — 성공/실패 무관하게 자동 close 금지. 결과 보고 후
   사용자 확인을 받고 **worker tab 만** close. workspace/LAUNCHER_TAB 은 보존.
   실패 시 tabs / panes / rcs 안내.
5. **인증 정책 불변** — API 키 사용 금지. OAuth CLI 만.
6. **인터랙티브 TUI only** — worker 는 항상 TUI 로 띄우고 prompt 는 `send-text` 로
   주입. `claude -p` / `codex exec` 등 headless one-shot 금지. spawn 후 worker
   tab 으로 focus 전환해 사용자가 실시간 관찰 가능하게 함.
7. **(v0.3) 모드 전환도 격리 가드 적용** — `toggle_mode` 는 `send_prompt` 와 동일하게
   송신 직전 pane tab_id 가 worker tab 인지(`is_worker_tab`) 검증. codex pane 에는
   `/effort` 를 보내지 않는다(no-op skip).

## resume 한계 경고 (v0.3)

dynamic workflow 는 **세션 종료 시 cross-session resume 불가** (다음 세션 fresh start).
herdr 워커 pane = 그 세션 자체이므로, workflow 진행 중인 pane 을 죽이면 그 안의
workflow 도 증발한다. cleanup(7단계)에서 "해당 pane 이 workflow 진행 중일 수 있으면
close 전 강한 경고" 를 안내할 것. (자동 감지는 v0.4 폴링 기능 — v0.3 은 문구 가드만.)

## 비기능 / 미구현 (v0.3 YAGNI)

다음은 본 버전 범위 밖. 필요해지면 별도 spec → 후속 버전.

- manifest.json / 영속 상태.
- resume 모드 (worker tab 닫히면 끝).
- 결과 자동 비교/diff/투표 알고리즘 — 호출자 자연어 처리.
- workflow 진행 폴링 중계 / 결과 펜스(`=== RESULT_JSON ===`) 자동 파싱 — v0.4 후보.
- pane 수 × pane 당 동시성 ≤ 물리 코어 예산 자동 배분 — v0.4 후보.
- TDD 파이프라인 (RED/GREEN), 디자인 일치도 검증 등 풀 파이프라인.
- bats 테스트 — 본 버전은 SKILL.md 중심.

## 변경 이력

- **v0.4** (2026-06-09) — **workspace 격리 → tab 격리 전환**. 새 workspace 를 만들지
  않고 호출자 workspace 를 공유, worker 는 매번 새 tab(`SLUG-batch`)에 배치 (workspace
  누적 불편 해소). `LAUNCHER_TAB`(orchestrator 본인 tab) 기록·격리, 격리 가드/cleanup 을
  tab 기준으로 전환(`is_worker_tab`, `herdr tab close` — workspace/LAUNCHER_TAB 보존).
  focus 전환도 `workspace focus` → `tab focus`. Preflight 의 focused pane 해석을
  `.result.panes[] | select(.focused==true)` fallback 으로 보정.
- **v0.3** (2026-05-29) — `WORKER_MODES` + `toggle_mode()` (세션 중간 effort/모드 전환,
  Opus 4.8 mid-conversation system message 로 cache 보존), effort 계층 규약, resume 한계
  경고. spec: `docs/superpowers/specs/2026-05-29-herdr-orchestrator-v0.3-toggle-mode.md`.
- **v0.2** — 인터랙티브 TUI only + focus 전환 + 확인 후 정리.
- **v0.1** — 최초 spawn/대기/회수/정리 primitive.

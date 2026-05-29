# herdr-orchestrator skill — v0.3 design spec (toggle_mode)

- date: 2026-05-29
- target marketplace: `gprecious-marketplace`
- plugin: `herdr`
- plugin version bump: `0.2.0` → `0.3.0` (기능 추가 = minor)
- 선행 spec: `2026-05-23-herdr-orchestrator-design.md` (v0.1/v0.2)
- 배경 리서치: `research/2026-05-29-claude-opus-4-8-ultracode-workflows-herdr/README.md`

## 1. 목적 / 동기

Claude Opus 4.8 + native dynamic workflows 시대에 herdr-orchestrator를 **"워커 런처"에서 "workflow 런처들의 런처"로** 한 단계 올린다. v0.3의 핵심은 한 가지: **워커 pane의 effort/모드를 세션 중간에 싸게 전환하는 `toggle_mode()` primitive**.

근거 — Opus 4.8의 **mid-conversation system message**:

- prompt cache는 접두사 캐시다. top-level `system` 필드를 수정하면 그 뒤 전체 컨텍스트의 캐시가 무효화 → 긴 워커 세션에서 모드를 바꿀 때마다 수십~수백 k 토큰을 full price로 재처리.
- Opus 4.8은 `role:"system"` 엔트리를 messages 배열 **꼬리**(user turn 직후)에 append할 수 있게 했다. 앞쪽 접두사가 byte-identical하게 유지되므로 **cache hit이 보존**된다.
- Claude Code의 `/effort` 슬래시(특히 `ultracode`)는 내부적으로 이 mid-conversation system message로 반영된다. 즉 워커 TUI에 `/effort ultracode`를 타이핑하면, 긴 컨텍스트 캐시를 날리지 않고 effort를 올릴 수 있다.

따라서 herdr 워커 세션에서 **"평소엔 가볍게, 깊은 구간에서만 ultracode"** 라는 동적 effort 운영이 경제적으로 가능해진다. v0.3는 이를 선언적(`WORKER_MODES`) + 명령적(`toggle_mode`) 두 경로로 노출한다.

## 2. 범위 (v0.3에 포함)

1. `WORKER_MODES` 배열 — slot별 초기 모드(선언적). 기본 `plain`.
2. `toggle_mode <slot_index> <mode>` 헬퍼 — 세션 중간 effort/모드 전환(명령적).
3. effort 계층 매핑 규약(prompt 가이드) — 워커=`xhigh`/`ultracode`, 워커가 띄우는 workflow subagent=`low`.
4. 안전 규칙 1항 추가(모드 전환도 격리 가드 적용).

**범위 밖(여전히 YAGNI)**: workflow 진행 폴링 중계, 결과 펜스 파싱, resume/manifest, CPU 캡 자동 배분 — 후속 버전(별도 spec).

## 3. `WORKER_MODES` (선언적)

`WORKER_CMDS` / `WORKER_PROMPTS`와 **index 정렬**되는 선택적 배열. 호출자가 안 채우면 전부 `plain`.

| 값                                          | 의미                                                                |
| ------------------------------------------- | ------------------------------------------------------------------- |
| `plain` (기본)                              | 모드 전환 없음 — Claude Code 기본 effort(`high`) 유지               |
| `ultracode`                                 | `/effort ultracode` — xhigh + 모든 substantive task에 workflow 자동 |
| `max` / `xhigh` / `high` / `medium` / `low` | 해당 effort 레벨로 시작                                             |

```bash
# 예: 깊은 감사 워커 2개는 ultracode, grind 워커 2개는 plain
WORKER_CMDS=(
  "claude --dangerously-skip-permissions"
  "claude --dangerously-skip-permissions"
  "codex --dangerously-bypass-approvals-and-sandbox"
  "codex --dangerously-bypass-approvals-and-sandbox"
)
WORKER_PROMPTS=( "$P0" "$P1" "$P2" "$P3" )
WORKER_MODES=(   "ultracode" "ultracode" "plain" "plain" )
```

길이 보정: 미지정 slot은 `plain`으로 채운다.

```bash
declare -a WORKER_MODES=("${WORKER_MODES[@]}")   # 호출자 정의 승계 (없으면 빈 배열)
for ((i=0; i<N; i++)); do : "${WORKER_MODES[$i]:=plain}"; done
```

## 4. `toggle_mode()` 헬퍼 (명령적)

```bash
# v0.3: 워커 pane 의 effort/모드를 세션 중간에 전환한다.
# Opus 4.8 mid-conversation system message 덕에, Claude Code 가 /effort 슬래시를
# messages 배열 "꼬리"에 system 엔트리로 반영 → 앞선 긴 컨텍스트의 prompt cache 가
# 보존된다 (top-level system 수정 시 발생하는 전체 재처리를 회피).
#
# 사용: toggle_mode <slot_index> <mode>
#   mode ∈ ultracode | max | xhigh | high | medium | low
# 전제:
#   - 해당 slot 이 claude 워커일 것 (codex 는 /effort 슬래시 없음 → skip).
#   - 호출 시점에 그 pane 이 입력 프롬프트 대기 상태일 것 (생성 중이면 슬래시가
#     큐잉되거나 무시될 수 있음). spawn 직후(prompt 주입 전) 또는 한 task 완료 후가 안전.
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

  # 3) 격리 가드 — pane workspace 가 WS_ID 와 일치할 때만 송신 (send_prompt 와 동일 규칙).
  local PANE_WS
  PANE_WS=$(herdr pane list \
            | jq -r --arg p "$PANE" '.result.panes[] | select(.pane_id==$p) | .workspace_id')
  [ "$PANE_WS" = "$WS_ID" ] || { echo "toggle_mode: pane $PANE workspace mismatch — abort"; return 1; }

  # 4) /effort 슬래시 주입. 슬래시는 모델 turn 을 소비하지 않고 즉시 처리되며,
  #    Claude Code 가 이를 mid-conversation system message 로 반영 → cache 보존.
  echo "toggle_mode: slot $I (ws:$PANE_WS) → /effort $MODE"
  herdr pane send-text "$PANE" "/effort $MODE"
  herdr pane send-keys "$PANE" Enter

  # 5) 적용 확인 — effort 라벨이 TUI 에 뜰 때까지 짧게 대기 (best-effort, 실패해도 계속).
  herdr wait output "$PANE" --match "$MODE" --timeout 8000 \
    || echo "toggle_mode: slot $I effort 라벨 확인 실패 (계속 진행)"
}
```

### 4.1 통합 지점 A — spawn 직후 초기 모드 적용 (prompt 주입 전)

기존 step 4(prompt 주입) 루프를, 모드 전환을 먼저 하도록 수정:

```bash
for ((i=0; i<N; i++)); do
  # v0.3: plain 이 아니면 prompt 주입 전에 모드 먼저 전환 (cache 보존 escalation).
  [ "${WORKER_MODES[$i]}" != "plain" ] && toggle_mode "$i" "${WORKER_MODES[$i]}"
  send_prompt "${PANES[$i]}" "${WORKER_PROMPTS[$i]}" || exit 1
done
```

순서가 중요: `/effort` 슬래시 → (step 5의 `wait output` 으로 반영 확인) → 실제 task prompt. 이래야 task가 올바른 effort에서 시작된다.

### 4.2 통합 지점 B — 단계별 재-escalation (선택, 고급)

한 워커를 "가볍게 1차 → 깊게 2차"로 운영하는 패턴. 1차 완료를 기다린 뒤 ultracode로 올리고 후속 prompt를 던진다. cache가 보존되므로 1차 컨텍스트를 그대로 들고 깊이만 키운다:

```bash
# slot 0 을 가볍게 1차 실행했다고 가정 (WORKER_MODES[0]=plain)
herdr wait agent-status "${PANES[0]}" --status done --timeout "$TIMEOUT_MS"

# 2차: ultracode 로 올리고 심화 prompt 주입
toggle_mode 0 ultracode
send_prompt "${PANES[0]}" "1차 결과를 바탕으로, workflow 로 전 구간을 교차검증해줘."
```

de-escalation도 동일: `toggle_mode 0 high` 로 기본 effort 복귀.

## 5. effort 계층 매핑 규약 (prompt 가이드)

herdr는 pane(=세션) 레벨 effort만 제어한다. 워커 안에서 dynamic workflow가 띄우는 **subagent의 effort는 워커가 작성하는 workflow 스크립트가 결정**한다. 따라서 이는 코드가 아니라 **prompt 규약**으로 강제한다:

- 워커(pane): `ultracode` 또는 `xhigh` — 깊은 판단·오케스트레이션 담당.
- 워커가 띄우는 workflow subagent: **`low` effort** 권장 — 단순 fan-out 작업은 저비용으로.

ultracode 워커에 prompt를 줄 때 다음 한 줄을 표준 접미로 포함:

> "workflow를 쓸 때 subagent는 low effort로 생성해 비용을 절감하고, 너(orchestrator pane)만 xhigh로 판단해라."

## 6. 안전 / 격리 규칙 (추가)

기존 5개 규칙에 1항 추가:

> 7. **모드 전환도 격리 가드 적용** — `toggle_mode` 는 `send_prompt` 와 동일하게 송신 직전 pane workspace_id == `WS_ID` 검증. codex pane 에는 `/effort` 를 보내지 않는다(no-op skip).

## 7. resume 한계 경고 (cleanup 연동)

dynamic workflow는 **세션 종료 시 cross-session resume 불가**(다음 세션 fresh start). herdr 워커 pane = 그 세션 자체이므로 pane을 죽이면 진행 중 workflow도 증발한다. → cleanup(step 7)에서 "해당 pane이 workflow 진행 중일 수 있으면 close 전 강한 경고"를 안내. (자동 감지는 v0.4 폴링 기능에서. v0.3은 문구 가드만.)

## 8. 파일 변경 목록

1. `claude-plugins/herdr/.claude-plugin/plugin.json` — version `0.2.0` → `0.3.0`.
2. `claude-plugins/herdr/skills/herdr-orchestrator/SKILL.md`:
   - 섹션 1(호출자 결정 변수)에 `WORKER_MODES` 추가 + 길이 보정.
   - 신규 섹션 `### 4.5 toggle_mode — 세션 중간 effort/모드 전환 (v0.3)`.
   - 섹션 4 prompt 주입 루프를 toggle_mode 선행 호출로 수정.
   - effort 계층 규약 한 줄 추가(협업 패턴 예시 옆).
   - 안전 규칙 7항 추가.
   - "비기능/미구현" 노트를 v0.3 기준으로 갱신.
3. `.agents/plugins/plugins/herdr/...` 미러 + 설치 캐시는 plugin sync/재설치로 반영.

## 9. 작업 순서

1. plugin.json version bump.
2. SKILL.md 편집(위 5개 변경).
3. (선택) 미러/캐시 동기화 — 마켓플레이스 sync 절차에 따름.
4. commit + push (사용자 확인 후).

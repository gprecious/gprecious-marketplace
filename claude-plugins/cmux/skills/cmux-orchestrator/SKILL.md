---
name: cmux-orchestrator
description: |
  cmux 멀티페인 터미널 위에서 Claude Code와 Codex 세션을 역할별 페인(plan / design /
  test-scenario / test-code / dev / review)으로 자동 오케스트레이션해 한 작업을 끝까지
  처리한다. 사용자가 "여러 페인 띄워서 만들어", "멀티 에이전트로", "오케스트레이션",
  "claude 와 codex 같이", "plan-dev-review 분리해서", "여러 역할로 나눠서 작업해줘",
  "feature 자동 개발", "병렬로 여러 agent" 같은 표현을 쓸 때 반드시 발동한다.
  단순 한 파일 편집이나 한 번의 자문에는 발동하지 말 것 — multi-step 구현 작업에서만.
  Figma 디자인 일치도 검증, RED 테스트 작성 후 GREEN 구현, AC 기반 단계별 검증을
  모두 포함하는 풀 파이프라인이다.
---

# cmux-orchestrator

cmux 워크스페이스 위에서 Claude Code 와 Codex 세션을 역할별 페인으로 자동 오케스트레이션하는 skill.

## 발동 조건 (description 외)

본 skill 은 **multi-step 구현 작업**에서만 발동. 단순 한 줄/한 파일 편집, 단발 자문은 다른 skill (`cmux-pane-chat`, `dispatching-parallel-agents`) 영역.

## 인증·과금 정책 (불변)

본 skill 은 **ANTHROPIC_API_KEY 또는 그 외 과금 API 키를 절대 사용하지 않는다.** 모든 모델 호출은 다음 둘 중 하나의 OAuth/구독 인증을 통한다:

- `claude --dangerously-skip-permissions` — Claude Code CLI (사용자 OAuth/구독)
- `codex --dangerously-bypass-approvals-and-sandbox` — Codex CLI (사용자 OAuth/구독)

orchestrator 도, 스폰된 페인도 anthropic / openai SDK 를 직접 import 하거나 `api.anthropic.com` 같은 엔드포인트로 직접 HTTP 호출을 보내지 않는다. 향후 이 skill 을 수정할 때 이 정책을 어기는 코드는 commit 거부 대상이다.

## 워크플로우

### 0. 사전 점검 + resume 감지

```bash
# cmux 환경 sanity
[ -n "$CMUX_SOCKET_PATH" ] || { echo "cmux 환경 아님"; exit 1; }
which cmux >/dev/null
which claude codex >/dev/null  # 페인 spawn 전 OAuth 로그인 확인

# resume 감지
slug=$(extract_slug_from_task_description "$TASK_DESC")  # 또는 사용자 인자 --resume <slug>
if [ -f "<repo>/.cmux-orchestrator/$slug/manifest.json" ]; then
  # 이전 manifest 발견 → critical 보고 후 resume mode
fi
```

### 1. Workspace 부트스트랩 (resume 아닐 때)

1. `cmux new-workspace --cwd <repo> --command "claude --dangerously-skip-permissions"` — 첫 페인은 plan(claude) 으로 시작 (단, `--here` 옵션 시 skip)
2. `cmux rename-workspace --workspace workspace:N <slug>` — workspace 이름을 slug 로 표시
3. `cmux new-pane --workspace workspace:N` 로 추가 페인 spawn — **target 페인 수 = 3 (페인당 2 surface tab)**. 6 페인 평면 spawn 은 width 가 좁아 사용자가 글자를 못 본다.
4. `cmux move-surface --surface surface:M --pane pane:K` 로 surface redistribute → 페인 3개에 surface 2개씩 그룹화. 빈 페인은 자동 close.
5. **`cmux refresh-surfaces` 호출** — 새 workspace 의 페인은 lazy-attach 라 PTY 가 자동 alloc 안 됨. `surface-health` 가 `in_window=false` 면 send/read 모두 `Surface is not a terminal` 에러. refresh-surfaces 가 attach 트리거. (move-surface 가 동시에 attach 트리거하기도 하지만 refresh 가 확실)
6. workspace 안에 `.cmux-orchestrator/<slug>/` + `_guides/` 디렉토리
7. `references/{cross-pane-chat,handoff-conventions,self-verify}.md` 를 `_guides/` 로 단순 복사
8. `scripts/manifest.sh` 의 `manifest_init` 호출
9. 5개 페인 (design, test-scenario, test-code, dev, review) 에 `claude` 또는 `codex` 실행 명령을 `cmux send` + `cmux send-key Enter` 로 전송 (각 페인은 default shell 로 spawn 되므로 명시적 부팅 필요)

### 2. Plan pane spawn → AC 도출

1. plan pane spawn (claude, persistent)
2. 부트스트랩 메시지 전송 (공통 헤더 + `references/pane-roles/plan.md` 본문)
3. send-and-poll → 응답 수신 → 01-plan.md 파일 존재 + manifest 갱신 확인
4. 2차 검증: AC 형식 lint
5. plan 의 task_classification 으로 다음 단계 분기 (`references/workflow.md`)

### 3. 분류별 단계 진행

`references/workflow.md` 의 adaptive pipeline 따름.

각 단계는 공통 패턴 (single-stage flow):

1. 페인 spawn (또는 persistent 재사용)
2. 부트스트랩 메시지 전송
3. send-and-poll
4. self-verify 결과 확인 (manifest)
5. orchestrator 2차 검증
6. ok → 다음 / fail → 1 retry → 그래도 fail → critical

### 4. (UI 작업 시) Design B 단계

`references/figma-integration.md` 의 B 단계 절차.

### 5. Review

review pane 에 변경 파일 list + AC 전송 → 06-review.md → blocker 있으면 dev 재투입 (1 retry).

### 6. 종료

- task-scoped pane 닫기 (test-scenario / test-code / dev)
- persistent pane 유지 (다음 작업에 재사용)
- orchestrator 가 사용자에게 결과 요약 + `.cmux-orchestrator/<slug>/` 경로 보고
- 사용자가 "끝" 명령 시 cmux close-workspace

## Critical decision 보고 형식

객관적 신호로 critical 판정 시 사용자에게 한 줄 보고. 예:

> ⚠ critical: 통합 테스트 3회 실패 (vitest 출력: src/foo.test.ts에서 timeout). dev pane 에 실패 로그 재투입했지만 같은 결과. .cmux-orchestrator/feature-x/manifest.json 의 stages.dev.failures 참고.

응답 안 기다리고 진행 (사용자 메모리: "허락 없이 바로 진행"). 사용자가 명시적으로 멈추면 paused.

## 참조 트리

- 워크플로우 분기 → `references/workflow.md`
- 모델 매핑 → `references/model-routing.md`
- Figma 절차 → `references/figma-integration.md`
- 실패/재개 → `references/failure-recovery.md`
- 페인 부트스트랩 메시지 schema → 본 SKILL.md 의 "부트스트랩 메시지 템플릿" 섹션 (아래)
- 역할별 본문 → `references/pane-roles/<role>.md`
- 페인용 가이드 (워크스페이스 \_guides/ 로 복사) → `references/{handoff-conventions,cross-pane-chat,self-verify}.md`

## 부트스트랩 메시지 템플릿

각 페인 spawn 직후 orchestrator 가 전송하는 단일 메시지. heredoc 임시파일에 작성 후 `cmux send --workspace {ws_ref} --surface surface:{N} "$(cat /tmp/<role>-bootstrap.txt)"` + `cmux send-key Enter` 로 전송. (큰 multi-line 메시지를 한 번에 안전 전송)

````text
당신은 cmux-orchestrator 워크플로우의 [{role}] 페인입니다.

## Workspace
- repo: {cwd}
- feature_slug: {slug}
- 매니페스트: .cmux-orchestrator/{slug}/manifest.json
- 가이드: .cmux-orchestrator/{slug}/_guides/
- workspace ref: {pane_ws_ref}    # 자기 페인의 workspace ref (e.g. workspace:4)

## 당신의 산출물
- 쓰기 대상: .cmux-orchestrator/{slug}/{artifact_filename}
- schema: 아래 "역할 본문" 참조

## 다른 페인 (cross-pane 자문 — cmux 호출 시 항상 --workspace 명시)
| 역할 | workspace | surface | 모델 | 상태 |
|------|-----------|---------|------|------|
| plan         | {pane_ws_ref}     | surface:{N1} | claude | ... |
| design       | {pane_ws_ref}     | surface:{N2} | claude | ... |
| test-scenario| {pane_ws_ref}     | surface:{N3} | claude | ... |
| test-code    | {pane_ws_ref}     | surface:{N4} | codex  | ... |
| dev          | {pane_ws_ref}     | surface:{N5} | codex  | ... |
| review       | {pane_ws_ref}     | surface:{N6} | claude | ... |
| orchestrator | {orch_ws_ref}     | surface:{N0} | claude | (별도 ws — orchestrator 본인) |

자문 필요 시 _guides/cross-pane-chat.md 규약 따름. 짧은 자문만, 작업 위임 금지,
상대 작업 중에는 메시지 보내지 말 것.

## Acceptance Criteria
{ac_list}    # plan 단계 이전이면 "(plan에서 정의 예정)"

## 완료 시 능동 보고 (필수)

작업 끝나면 orchestrator 에게 cmux send 로 능동 보고:

```bash
cmux send --workspace {orch_ws_ref} --surface surface:{N0} \
  "[from {role}] {role} done. artifact: .cmux-orchestrator/{slug}/{artifact_filename} ({size}). self-verify: <ok|partial:사유>"
cmux send-key --workspace {orch_ws_ref} --surface surface:{N0} Enter
````

orchestrator 가 그 메시지를 prompt 입력으로 받아 즉시 다음 단계 결정. 보고가 묵살되더라도(orchestrator 가 다른 작업 중) orchestrator 가 자체 polling 으로 회수하니 별도 retry 불필요.

## 완료 시 self-verify

1. \_guides/self-verify.md 의 [{role}] 체크리스트 실행
2. manifest.stages.{role}.self_verified 에 결과 + evidence 기록
3. 위 "능동 보고" 한 번 전송

## 안전

- destructive 명령 금지
- 워크스페이스 .cmux-orchestrator/ 외부 쓰기 금지 (단, dev pane은 repo 본 코드 가능)
- 모르겠으면 orchestrator 에게 한 줄 보고 후 대기 (능동 보고와 동일 방식)
- figma MCP 직접 호출 금지 — orchestrator 가 사전 정리한 frame 정보 또는 사용자가 별도로 준 정보만 사용 (figma-mcp 가 hang 되는 경우 대비)

---

{role_body}

````

치환 변수:

- `{role}`, `{cwd}`, `{slug}`, `{artifact_filename}`, `{ac_list}`, `{N0..N6}`, `{role_body}`
- `{pane_ws_ref}` = 페인들이 spawn 된 workspace ref (e.g. `workspace:4`)
- `{orch_ws_ref}` = orchestrator 본인이 떠있는 workspace ref (보통 `workspace:1` 같은 사용자 본 워크스페이스)
- `{role_body}` = `references/pane-roles/{role}.md` 의 본문 (frontmatter 제외)

## scripts 사용 안내

- `scripts/manifest.sh`: manifest 갱신 헬퍼. 항상 `MANIFEST_PATH` env 설정 후 source.
- `scripts/pane-status.sh`: capture 분석 (idle/dead/failure 신호 / context %).
- `scripts/send-and-poll.sh`: cmux send + Enter + polling (cmux send-key Enter 함정 회피).
- `scripts/compact-or-fork.sh`: context % 임계 시 /compact 또는 fork 결정.

각 스크립트의 함수는 source 후 직접 호출.

## cmux 운용 노하우 (실전 검증)

### Workspace / Pane / Surface 모델

- **window** > **workspace** > **pane** > **surface** 의 4계층. orchestrator 는 사용자 본 워크스페이스에 머물고, 작업 페인들은 별도 workspace 에 spawn.
- **페인 = 화면 분할 단위**. 한 페인 안에 surface 여러 개를 탭처럼 쌓을 수 있음 (`move-surface --pane` 으로 이동).
- **권장 레이아웃 = 3 페인 × 페인당 surface 2개**. 6 페인 평면 spawn 은 가로폭이 좁아 사용자가 글자를 못 본다. 페인이 너무 좁으면 무조건 그룹화.

### 새 workspace 페인의 lazy-attach 함정

- 새 workspace 의 페인은 **`in_window=false`** 상태. PTY 가 자동 alloc 안 됨.
- 이 상태에서 `cmux send` / `cmux read-screen` 하면 **`Surface is not a terminal`** 에러.
- **해결**: `cmux refresh-surfaces` 호출. PTY attach 트리거. (`select-workspace` 만으로는 부족. `move-surface` 가 부수효과로 attach 트리거 하기도 함.)
- 검증: `cmux surface-health --workspace workspace:N` 으로 `in_window=true` 확인.

### --workspace 명시 필수

- `cmux send --surface surface:N "..."` 만 쓰면 workspace ambiguity. 항상 `--workspace workspace:M --surface surface:N` 풀로 명시.
- 부트스트랩 메시지에 cross-pane chat 예시 적을 때도 `--workspace` 포함된 형태로 줘야 페인이 따라할 수 있음.

### send-key 함정

- `cmux send-key --surface surface:N C-c` 는 **unknown key**. Ctrl-C 형식 안 먹힘.
- 정식 키만 확실: `Enter`, `Tab`, `Escape`, `Up`/`Down`/`Left`/`Right`.
- 잘못 입력된 명령 cancel 이 필요하면: 공백 Enter 한 번 → 새 prompt 줄 확보 → 다시 명령 입력. (또는 사용자에게 cmux GUI 에서 직접 Ctrl-C 부탁)

### 큰 multi-line 메시지 안전 전송

- 부트스트랩 메시지 (수십~수백 라인) 는 `cmux send "..."` 의 인자로 직접 넣지 말고:
  ```bash
  cat > /tmp/<role>-bootstrap.txt <<'EOF'
  ...메시지 본문...
  EOF
  cmux send --workspace workspace:N --surface surface:M "$(cat /tmp/<role>-bootstrap.txt)"
  cmux send-key --workspace workspace:N --surface surface:M Enter
````

- heredoc 안에서 `\` 이스케이프, `${VAR}` 치환 모두 사용 가능. `'EOF'` (따옴표) 로 감싸면 변수 치환 비활성.

### 페인 spawn 후 명시적 부팅

- `cmux new-pane --workspace workspace:N` 은 페인 + default shell 만 spawn. claude/codex 가 자동으로 안 뜸.
- spawn 후 `cmux send "claude --dangerously-skip-permissions"` + `Enter` 로 명시적 부팅 필수.
- 첫 페인만 예외: `cmux new-workspace --command "claude --dangerously-skip-permissions"` 로 동시에.

### figma MCP hang 회피

- `figma` MCP 가 `mcp-remote` 래퍼 (npx) 로 등록되어 있으면 stdio↔HTTP 변환에서 hang 가능.
- 진단: `claude mcp list` 로 등록 형태 확인 → `npx -y mcp-remote@latest http://127.0.0.1:3845/mcp` 면 래퍼.
- 해결:
  ```bash
  claude mcp remove figma
  claude mcp add --transport http figma http://127.0.0.1:3845/mcp
  ```
  Claude Code 세션 reload 필요 (현재 세션의 `mcp__figma__*` 도구는 disconnect).
- **차선 (reload 못 할 때)**: 페인의 다른 Claude/Codex 세션이 figma MCP 호출해서 결과만 cross-pane chat 으로 orchestrator 에 전달. orchestrator 는 그 정보로 부트스트랩 메시지 작성.

### 페인 → orchestrator 능동 보고

- 페인이 작업 끝나면 자체적으로 orchestrator 페인에 `cmux send` 로 결과 보고. 메시지가 orchestrator 의 prompt 입력으로 들어가서 즉시 다음 단계 결정 가능.
- 메시지 형식 예: `[from {role}] {role} done. artifact: <path> ({size}). self-verify: ok|partial:사유`
- 안전망 polling 도 병행 — 능동 보고가 orchestrator 가 다른 작업 중이거나, send 가 silent fail 한 경우 대비.
- polling 간격: 10초, 산출물 파일 + 화면 idle 동시 충족 시 종료. timeout 60분 (dev 처럼 긴 작업) 은 별도 wake 스케줄로 cache 비용 절약.

### 페인 부팅 sanity check

```bash
# spawn → send 사이에 필수
cmux refresh-surfaces
cmux surface-health --workspace workspace:N | grep -v "in_window=true" && echo "주의: 일부 페인 미attach"

# 모든 페인 부팅 확인 (claude/codex CLI 시작 화면 검출)
for s in 10 11 12 13 14 15; do
  cmux read-screen --workspace workspace:N --surface surface:$s --lines 5 | grep -qE "Claude Code|Codex" \
    && echo "surface:$s OK" \
    || echo "surface:$s 부팅 미완료"
done
```

```

```

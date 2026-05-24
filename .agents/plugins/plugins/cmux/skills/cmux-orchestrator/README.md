# cmux-orchestrator

cmux 워크스페이스 위에서 Claude Code 와 Codex 세션을 역할별 페인으로 자동 오케스트레이션해 한 작업을 끝까지 처리하는 skill.

## 환경 요구

- macOS + cmux.app 설치
- claude CLI 로그인 완료 (OAuth/구독 — API key 불필요)
- codex CLI 로그인 완료 (OAuth/구독 — API key 불필요)
- jq, bash 4+, bats (테스트)
- 선택: Playwright (UI 일치도 검증), Figma MCP (design pane)

## 인증·과금 정책 (불변)

본 skill 은 **ANTHROPIC_API_KEY 또는 그 외 과금 API 키를 절대 사용하지 않는다.** 모든 모델 호출은 `claude --dangerously-skip-permissions` (Claude Code OAuth) 와 `codex --dangerously-bypass-approvals-and-sandbox` (Codex OAuth) 만으로 이루어진다. anthropic / openai SDK 직접 import, `api.anthropic.com` 같은 엔드포인트 직접 HTTP 호출 모두 금지.

## 사용

```bash
# 슬래시 명령 (Claude Code 안에서)
/cmux-orchestrator:cmux-orchestrate "기능 X 만들어줘"

# 또는 자연어 트리거
"여러 역할로 나눠서 X 만들어줘"
```

## 옵션

- `--resume [slug]`: 작업 재개
- `--here`: 현재 workspace 에 페인 추가 (기본: 새 workspace)
- `--visualization-command "<cmd>"`: UI 검증용 dev 서버/storybook 명령

## 디렉토리 구조

```
~/.claude/skills/cmux-orchestrator/
├── SKILL.md
├── commands/cmux-orchestrate.md
├── scripts/
│   ├── manifest.sh
│   ├── pane-status.sh
│   ├── send-and-poll.sh
│   └── compact-or-fork.sh
├── references/
│   ├── workflow.md
│   ├── model-routing.md
│   ├── figma-integration.md
│   ├── failure-recovery.md
│   ├── handoff-conventions.md
│   ├── cross-pane-chat.md
│   ├── self-verify.md
│   └── pane-roles/
│       ├── plan.md
│       ├── design.md
│       ├── test-scenario.md
│       ├── test-code.md
│       ├── dev.md
│       └── review.md
├── evals/evals.json
└── tests/
    ├── scripts/      (bats 테스트)
    └── fixtures/     (capture mock)
```

## 테스트 실행

```bash
cd ~/.claude/skills/cmux-orchestrator
bats tests/scripts/
```

## 정책 hook 설치 (선택)

API key / SDK 도입 차단 pre-commit hook 설치:

```bash
cd ~/.claude/skills/cmux-orchestrator
./scripts/install-hooks.sh
```

## 트러블슈팅

| 증상             | 원인 / 대응                                                                         |
| ---------------- | ----------------------------------------------------------------------------------- |
| "cmux 환경 아님" | cmux.app 안에서 실행해야 함. `$CMUX_SOCKET_PATH` 비어있으면 그냥 일반 터미널.       |
| pane spawn 실패  | cmux 권한 prompt 가 떠있을 수 있음. cmux 화면 확인.                                 |
| 모델 한도 메시지 | rate limit 자동 sleep 후 재시도. billing 한도면 즉시 critical (사용자 처리).        |
| context 폭증     | 60% 에서 /compact, 85% 에서 fork. 사용자가 한 작업이 너무 크면 spec 을 잘게 나누기. |

## 디자인 spec

`docs/superpowers/specs/2026-04-29-cmux-orchestrator-design.md` (별도 위치)

## 라이선스 / 책임

본 skill 은 `--dangerously-skip-permissions` 와 `--dangerously-bypass-approvals-and-sandbox` 를 사용한다. cmux 워크스페이스 자체를 sandbox 로 보고 사용자가 동의한 환경에서만 사용. destructive 명령은 모든 페인에서 금지로 강제하지만 100% 보장 아님 — 사용자가 워크플로우를 모니터링.

## Dry-run procedure

cmux 환경에서 처음 사용 전 소규모 bugfix 로 동작 확인 절차.

### Step 1: dry-run 시나리오 선택

QPLACE 레포에서 작은 버그 (예: `apps/api-qplace-v2/src/util/<유틸>` 의 단순 함수) 를 골라:

```
/cmux-orchestrator:cmux-orchestrate "apps/api-qplace-v2/src/util/<file>.ts 의 <함수> 가 빈 문자열 입력 시 throw 안 함. 빈 문자열 → ''로 반환되게 fix. AC 정의 → RED 테스트 → fix → review."
```

### Step 2: 워크플로우 진행 모니터링

체크포인트:

- plan pane 이 스폰되고 `01-plan.md` 작성
- AC 가 명제 형식으로 1개 이상
- `task_classification = bugfix`
- test-code pane 이 RED 확인
- dev 가 통과
- review 가 통과 또는 minor 만

### Step 3: 발견된 이슈 패치

일어난 이슈를 `issues.md` 에 기록 후 hotfix 커밋.

### Step 4: 문제없으면 실제 작업 투입

dry-run 통과 후 실제 feature 작업에 사용.

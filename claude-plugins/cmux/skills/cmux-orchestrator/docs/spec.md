# cmux-orchestrator Skill — Design Spec

- **상태**: Draft (사용자 검토 대기)
- **작성일**: 2026-04-29
- **작성자**: Claude Code (brainstorming with harry@qplace.kr)
- **대상 위치**: `~/.claude/skills/cmux-orchestrator/` (글로벌 skill, 특정 레포에 종속되지 않음)
- **참조**:
  - `~/.claude/skills/cmux-pane-chat/SKILL.md` — pane 간 통신 규약
  - `~/.claude/skills/dispatching-parallel-agents/SKILL.md` — 병렬 분기 패턴
  - `~/.claude/plugins/cache/claude-plugins-official/skill-creator/.../skills/skill-creator/SKILL.md` — skill 작성 가이드
  - cmux CLI: `/Applications/cmux.app/Contents/Resources/bin/cmux`
  - codex CLI, claude CLI
  - karpathy guidelines (`.claude/skills/karpathy-guidelines/SKILL.md`)

## 1. 목적과 사용 시나리오

cmux 워크스페이스 위에서 Claude Code와 Codex CLI 세션을 역할별 페인으로 동시 가동하여 한 작업을 plan → (design) → test-scenario → test-code + dev → (design-verify) → review 흐름으로 끝까지 자동 처리한다. 사용자는 critical decision 시점에만 한 줄 보고를 받고, 그 외에는 진행을 위임한다.

**발동 케이스**:

- 새 기능을 multi-step으로 구현 (UI 유무 무관)
- 버그 수정에 RED 테스트 → fix → review 풀 사이클이 필요
- 리팩토링 후 기존 테스트 통과 + 디자인 일관성 검증이 필요
- Figma 디자인이 있는 UI 기능 — 일치도 자동 검증 포함

**발동하지 않는 케이스** (description에 명시):

- 한 줄/한 파일 단순 편집
- 단발 자문 (옆 페인 codex에게 한 번 묻는 정도) — 이건 `cmux-pane-chat` skill 영역
- 서로 무관한 여러 테스트 동시 디버깅 — 이건 `dispatching-parallel-agents` skill 영역

## 2. 핵심 결정 (사용자 합의)

| 영역           | 결정                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------------- |
| 자동화 수준    | **풀 자동 + critical decision 시 사용자 한 줄 보고**                                              |
| Pane 생명주기  | **하이브리드** — plan/design/review = persistent, test-scenario/test-code/dev = task-scoped       |
| 모델 매핑      | **휴리스틱 + override** — 기본 매핑 있고 task complexity 따라 조정                                |
| 핸드오프       | **파일 + manifest** 메인, 페인 간 자문은 `cmux send` 직접 (모든 페인이 cross-pane chat 능력 보유) |
| Workspace 단위 | **새 cmux workspace 자동 생성** (`--here` 옵션으로 현재 workspace 사용 가능)                      |
| 트리거         | **슬래시 명령 + 자연어 키워드 둘 다**                                                             |
| Skill 구조     | **단일 skill** — `references/` 와 `scripts/` 로 분리 (progressive disclosure)                     |
| 검증           | **2단계** — pane self-verify + orchestrator 2차 검증, manifest에 evidence 기록                    |
| Figma          | **design pane이 두 시점 작동** — A: 분석, B: dev 후 일치도 검증                                   |

## 3. 아키텍처

```
[사용자 cmux workspace]
    └─ Claude Code (orchestrator, 본 skill 보유)
        └─ /cmux-orchestrator:cmux-orchestrate "task"  또는 자연어 트리거
            └─ cmux new-workspace "orchestrate-<slug>"
                ├── .cmux-orchestrator/<slug>/
                │   ├── manifest.json                  (single source of truth)
                │   ├── _guides/                       (페인용 압축 가이드 복사본)
                │   ├── 01-plan.md ... 06-review.md
                │   ├── 07-design-verify.md            (UI 작업 시)
                │   └── screenshots/                   (visual verify 시)
                │
                ├── persistent panes (plan / design / review) — Claude
                └── task-scoped panes (test-scenario / test-code / dev) — Claude/Codex
```

핵심 불변 조건:

- `manifest.json` 이 모든 상태의 single source of truth. 페인이나 orchestrator가 죽어도 manifest만 살아있으면 재개 가능.
- 페인은 자기 산출물 파일과 `_guides/` 외부에 쓰기 금지 (단 dev pane은 repo 본 코드 수정 허용).
- destructive 명령 (`rm -rf`, `git reset --hard`, 마이그레이션) 모든 페인에서 금지.

## 4. Skill 디렉토리 구조

```
~/.claude/skills/cmux-orchestrator/
├── SKILL.md                                  # frontmatter + 워크플로우 결정 트리 (~400줄)
├── commands/
│   └── cmux-orchestrate.md                   # /cmux-orchestrator:cmux-orchestrate
├── scripts/
│   ├── ensure-cmux.sh
│   ├── spawn-workspace.sh
│   ├── spawn-pane.sh
│   ├── send-and-poll.sh                      # send + Enter + idle-detect 폴링 + capture
│   ├── pane-status.sh                        # idle / working / dead 판정
│   ├── manifest.sh                           # manifest.json 헬퍼
│   ├── compact-or-fork.sh                    # 토큰 임계 시 분기
│   └── cleanup-workspace.sh
├── references/
│   ├── workflow.md                           # task 분류 → 단계 선택 휴리스틱
│   ├── model-routing.md                      # 역할별 모델 디폴트 + override
│   ├── pane-roles/
│   │   ├── plan.md
│   │   ├── design.md
│   │   ├── test-scenario.md
│   │   ├── test-code.md
│   │   ├── dev.md
│   │   └── review.md
│   ├── figma-integration.md
│   ├── handoff-conventions.md                # 파일 명명, manifest 스키마, 갱신 규약
│   ├── cross-pane-chat.md                    # cmux-pane-chat 압축 가이드 (페인이 읽음)
│   ├── self-verify.md                        # 역할별 self-verify 체크리스트 표준
│   └── failure-recovery.md
└── evals/
    └── evals.json
```

진보적 공개:

- L1 metadata: `description` 만 항상 컨텍스트에 (트리거 단어 다양화).
- L2 SKILL.md 본문: orchestrator의 메인 흐름.
- L3 `references/` 안의 파일: 필요 시점에만. `pane-roles/` 의 각 파일은 해당 페인 부트스트랩 시점에 발췌하여 페인 메시지에 인라인 (페인 자체는 skill 보유 X).

워크스페이스 부트스트랩 시 `references/cross-pane-chat.md`, `handoff-conventions.md`, `self-verify.md` 를 `<repo>/.cmux-orchestrator/<slug>/_guides/` 로 단순 복사 — 페인이 본인 cwd 기준으로 Read 가능.

## 5. Orchestrator 워크플로우

### 5.1 Adaptive pipeline — task 분류로 단계 가지치기

```
plan pane이 응답한 task_classification 에 따라:

new-feature-no-ui    → plan → test-scenario → test-code + dev (병렬) → review
new-feature-with-ui  → plan → design → test-scenario → test-code + dev → design-verify → review
bugfix               → plan(축약) → test-code(failing repro) → dev → review
refactor             → plan → dev → 기존 테스트 통과 검증 → review
design-only          → design (Figma 분석/제안) → review
```

분류 자체가 모호하면 critical → 사용자 보고 후 진행.

### 5.2 단계 공통 패턴

```
[stage]
  1. orchestrator: 이전 산출물 경로를 부트스트랩에 포함하여 pane spawn 또는 재사용
  2. orchestrator: cmux send + Enter 로 부트스트랩 메시지 전송
  3. pane: 작업 → 산출물 파일 작성 → self-verify 실행 → manifest.stages.<role>.self_verified 갱신
  4. pane: orchestrator 에게 "<role> done" 한 줄 응답
  5. orchestrator: send-and-poll.sh 로 응답 수신
  6. orchestrator: 2차 검증 (산출물 schema lint, 테스트 재실행, AC 매트릭스 등) → manifest.stages.<role>.orchestrator_verified 갱신
  7. ok 면 다음 단계, 실패면 재요청 (1 retry; 즉 첫 시도 + 1회 재시도 = 총 2회). 두 번 다 실패면 critical.

여기서 "1 cycle / 1 retry" = "원래 시도 1번 + 재시도 1번" 으로 spec 전체에서 통일한다.
```

### 5.3 Critical decision 발동 조건 (객관적 신호만)

- pane dead (capture 동일 60s + 모델 footer 없음) — 재spawn도 실패
- 통합 테스트 3회 연속 실패
- 모델 한도/billing 메시지 (문자열 매칭)
- task 분류 불가능 (plan pane 응답 모호)
- self-verify 또는 orchestrator 2차 검증 2회 실패
- design 일치도 retry 후에도 partial/fail 잔여
- resume 모드에서 이전 manifest 발견

주관적 판정("scope 변경", "destructive change") 은 critical 판정 기준에서 제외 — false positive 위험.

## 6. 성공 기준 (AC) + 2단계 검증

### 6.1 AC 흐름

`plan` pane이 task 를 검증 가능한 명제 형태의 AC로 분해 → 모든 후속 페인의 부트스트랩 prompt에 그대로 주입 → 페인은 "이 AC를 어떻게 만족시킬지/검증할지"만 답함.

AC 형식 강제:

- 나쁨: "유저가 신청서를 제출할 수 있다" (행위)
- 좋음: "POST /applications 200 응답 + DB row 1개 생성 + 동일 폼버전 중복 제출 시 409" (명제)

### 6.2 페인별 검증 매트릭스

| 역할          | self-verify                                                                        | orchestrator 2차 검증                                   |
| ------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------- |
| plan          | AC ≥ 1, 각 AC 명제 형식, 분류 enum 매칭                                            | AC 형식 lint (`AC-N` 패턴, 명사구 거부)                 |
| design        | Figma 컴포넌트/토큰 매핑 표 1개+                                                   | plan AC 중 UI 항목이 design 표에 1:1 대응               |
| test-scenario | 모든 AC가 시나리오 ≥ 1개에 매핑                                                    | AC × 시나리오 매트릭스 검사 (빈 셀 거부)                |
| test-code     | 작성한 테스트 즉시 실행, 모두 RED 확인                                             | orchestrator가 동일 명령 재실행, RED 일치               |
| dev           | `pnpm test --run`, `pnpm lint` 통과 출력 첨부                                      | orchestrator가 cwd에서 같은 명령 재실행, 출력 비교      |
| review        | 발견 이슈 actionable 형태 (severity / path:line / suggestion), 0건이면 "통과" 명시 | actionable item만 dev 재투입, 형식 위반은 review 재요청 |

### 6.3 Figma 일치도 검증 (`07-design-verify.md`)

dev pane self_verified=true 시 orchestrator 가:

1. `05-dev.md` 의 변경된 페이지/컴포넌트 경로 추출
2. `manifest.visualization_command` (사용자가 초기에 지정 — 예: `pnpm storybook`, `pnpm dev-app`) 실행
3. Playwright로 자동 스크린샷 → `screenshots/<component>-actual.png`
4. design pane에 "B 단계: Figma frame과 스크린샷 비교, 07-design-verify.md 작성" 전송
5. design pane이 정성 평가표 작성 (spacing / color / component variant / layout)
6. `match_status` ∈ {pass, partial, fail}

후속:

- pass → review 단계
- partial → fix_hint 묶어서 dev 재투입, 재검증 (1 retry — Section 5.2 정의와 동일)
- fail 또는 retry 후에도 partial 잔여 → critical

Figma URL이 없는 경우 (plan에서 `figma_frame_urls` 비어있음) 본 절 (Figma 일치도 검증) 전체 skip.

## 7. Pane 부트스트랩 메시지

각 페인이 spawn 직후 받는 단일 메시지. orchestrator가 `cmux send` + Enter 로 전송.

### 7.1 공통 헤더 (~50줄)

```text
당신은 cmux-orchestrator 워크플로우의 [{role}] 페인입니다.

## Workspace
- repo: {cwd}
- feature_slug: {slug}
- 매니페스트: .cmux-orchestrator/{slug}/manifest.json
- 가이드: .cmux-orchestrator/{slug}/_guides/

## 당신의 산출물
- 쓰기 대상: .cmux-orchestrator/{slug}/{artifact_filename}
- schema: 아래 "역할 본문" 참조

## 다른 페인 (cross-pane 자문)
| 역할 | surface | 모델 |
|------|---------|------|
| plan         | surface:{N1} | claude |
| design       | surface:{N2} | claude |
| test-scenario| surface:{N3} | claude |
| test-code    | surface:{N4} | codex  |
| dev          | surface:{N5} | codex  |
| review       | surface:{N6} | claude |
| orchestrator | surface:{N0} | claude |

자문 필요 시 _guides/cross-pane-chat.md 규약 따름. 짧은 자문만, 작업 위임 금지,
상대 작업 중에는 메시지 보내지 말 것.

## Acceptance Criteria
{ac_list}    # plan 단계 이전이면 "(plan에서 정의 예정)"

## 완료 시 self-verify
1. _guides/self-verify.md 의 [{role}] 체크리스트 실행
2. manifest.stages.{role}.self_verified 에 결과 + evidence 기록
3. orchestrator 에게 "{role} done" 한 줄 응답

## 안전
- destructive 명령 금지
- 워크스페이스 .cmux-orchestrator/ 외부 쓰기 금지 (단, dev pane은 repo 본 코드 가능)
- 모르겠으면 orchestrator 에게 한 줄 보고 후 대기

---

{role_body}
```

치환 변수: `{role}`, `{cwd}`, `{slug}`, `{artifact_filename}`, `{ac_list}`, `{N0..N6}`, `{role_body}`.

### 7.2 역할별 본문 (`references/pane-roles/<role>.md`)

각 파일 ~30줄. 산출물 schema 와 self-verify 체크리스트가 핵심. 아래는 spec 단계의 schema 정의 — implementation plan에서 본 schema에 맞춰 각 파일을 작성한다.

#### 7.2.1 plan.md

임무: task description 을 검증 가능한 AC 로 분해.

산출물 (`01-plan.md`):

```markdown
# Plan: {slug}

## 분류

new-feature-no-ui | new-feature-with-ui | bugfix | refactor | design-only

## Acceptance Criteria

- AC-1: <명제 형식. "X 한다" 가 아니라 "X 가 일어났을 때 Y 가 검증된다">
- AC-2: ...

## 제약

- ...

## 위험 / 가정

- ...

## (UI 있는 경우) 관련 Figma frames

- url1, url2...
```

self-verify: AC ≥ 1 / 각 AC 명제 형식 / 분류가 5 enum 중 하나 / UI 있는 분류면 figma url ≥ 1개 또는 명시적 "Figma 없음".

#### 7.2.2 design.md

임무 (A 단계, plan 후): `02-design.md` 에 Figma 컴포넌트/토큰 매핑.

산출물 (`02-design.md`):

```markdown
# Design: {slug}

## figma_frame_urls

- url1, url2...

## 컴포넌트 매핑

| figma 컴포넌트 | design-system 매핑                   | 비고 |
| -------------- | ------------------------------------ | ---- |
| Button/Primary | `<Button variant="primary">`         |      |
| Input/Text     | `<TextField>`                        |      |
| ...            | (없으면 "신규 필요" + 제안 컴포넌트) |      |

## 토큰 매핑

| 카테고리 | figma 값 | design-system 토큰 |
| -------- | -------- | ------------------ |
| color    | #1A56FF  | `color-brand`      |
| spacing  | 32px     | `gap-8`            |
```

self-verify: figma_frame_urls 비어있지 않음 / 컴포넌트 매핑 표 1개+ / 토큰 매핑 표 1개+ / 모든 figma frame 이 표에 등장.

임무 (B 단계, dev 후): `07-design-verify.md` 작성. 6.3 참조.

산출물 (`07-design-verify.md`):

```markdown
# Design verify: {slug}

## AC 별 일치도

### AC-3: <text>

- Figma frame: <url>
- 구현 스크린샷: screenshots/<file>.png
- match_status: pass | partial | fail

#### Pass 항목

- ✓ 색상 (color-brand)
- ✓ 폰트 크기

#### Partial / Fail 항목

| type      | location | expected | actual | fix_hint           |
| --------- | -------- | -------- | ------ | ------------------ |
| spacing   | ...      | 32px     | 16px   | <path>:<line> mt-8 |
| component | ...      | ...      | ...    | size="lg" 누락     |
```

self-verify: 모든 UI 관련 AC 가 1개 이상 항목으로 다뤄짐 / match_status 가 enum / partial/fail 항목은 fix_hint 채워짐.

#### 7.2.3 test-scenario.md

임무: 각 AC 마다 시나리오 ≥ 1.

산출물 (`03-test-scenarios.md`):

```markdown
# Test scenarios: {slug}

## AC-1: <text>

### S1: <간단 제목>

- 입력: ...
- 실행: ...
- 기대: ...

### S2: ...

## AC-2: ...
```

self-verify: 모든 AC 가 시나리오 ≥ 1개 / 시나리오마다 입력 + 기대 명시.

#### 7.2.4 test-code.md

임무: 시나리오 → 실패하는 테스트 (RED) 작성. 즉시 실행해서 모두 RED 임을 확인.

산출물 (`04-test-code.md`):

```markdown
# Test code: {slug}

## 작성 파일

- `<path>`: 함수명 list

## 실행 명령

- `pnpm test --run <path>`

## RED 증거

(vitest 출력 발췌; "X failed, 0 passed" 등)
```

self-verify: 모든 시나리오 → 테스트 매핑 / 모두 RED / 명령 재현 가능.

#### 7.2.5 dev.md

임무: plan + (design) + 시나리오 보고 구현. test-code 의 테스트 통과시키는 게 1차 목표.

제약: 같은 파일을 test-code 페인이 동시 편집하지 않음 (test-code 는 `*.test.*` 만, dev 는 본 코드만).

산출물 (`05-dev.md`):

```markdown
# Dev: {slug}

## 변경 파일

- <path>

## 결정 로그

- "X 대신 Y 선택, 이유: Z"

## self-verify

### 테스트

(pnpm test --run <paths> 출력; "X passed, 0 failed")

### lint

(pnpm lint 출력; clean)
```

self-verify: 04 의 명령이 GREEN / lint 통과.

#### 7.2.6 review.md

임무: 05 의 변경 파일 검토.

산출물 (`06-review.md`):

```markdown
# Review: {slug}

## 발견 이슈

(이슈 0건이면 "통과" 한 줄 명시)

| severity            | path:line     | issue | suggestion |
| ------------------- | ------------- | ----- | ---------- |
| blocker/major/minor | src/foo.ts:42 | ...   | ...        |

## AC 검증

- AC-1: ✓ — 코드 근거 (path:line)
- AC-2: ✗ — 이유
- AC-3: N/A — 본 작업 범위 아님
```

self-verify: 모든 AC 가 ✓/✗/N/A 중 하나, 이슈 0건이면 "통과" 명시 / 모든 이슈에 severity + path:line + suggestion.

## 8. Manifest 스키마

```json
{
  "schema_version": 1,
  "feature_slug": "string",
  "task_classification": "new-feature-no-ui | new-feature-with-ui | bugfix | refactor | design-only | unknown",
  "task_description": "string",
  "started_at": "ISO-8601",
  "last_updated": "ISO-8601",
  "status": "in_progress | paused | done | aborted",
  "workspace_id": "cmux workspace ref",
  "visualization_command": "string | null",
  "panes": {
    "surface:N": {
      "role": "plan | design | test-scenario | test-code | dev | review",
      "model": "claude | codex",
      "lifecycle": "persistent | task-scoped",
      "spawned_at": "ISO-8601",
      "alive_check_at": "ISO-8601",
      "alive": true
    }
  },
  "acceptance_criteria": [
    {
      "id": "AC-1",
      "text": "...",
      "verified_by": ["test-code", "dev"]
    }
  ],
  "stages": {
    "plan": {
      "status": "pending | running | done | failed | paused | skipped",
      "pane_ref": "surface:N",
      "artifact": "01-plan.md",
      "started_at": "ISO-8601",
      "ended_at": "ISO-8601",
      "self_verified": {
        "ok": true,
        "checklist": ["AC ≥1: ✓", "명제 형식: ✓"],
        "evidence": "01-plan.md 검토 결과"
      },
      "orchestrator_verified": {
        "ok": true,
        "evidence": "AC 3개, 모두 명제 형식, 분류 enum 매칭"
      }
    }
  },
  "design_verification": {
    "match_status": "pass | partial | fail | n/a",
    "verified_acs": ["AC-3"],
    "issues_count": 0,
    "artifact": "07-design-verify.md"
  }
}
```

## 9. 실패·복구 정책

### 9.1 실패 카테고리 → 자동 대응 → critical 트리거

| 케이스                  | 감지                                       | 자동 대응                                     | critical                      |
| ----------------------- | ------------------------------------------ | --------------------------------------------- | ----------------------------- |
| Pane spawn 실패         | cmux exit code                             | 1회 재시도 (1s 후)                            | 2회 실패                      |
| Pane dead               | capture 동일 60s + footer 없음             | pane 재spawn + 부트스트랩 재전송              | 재spawn도 dead                |
| 모델 rate limit         | "rate limit" / "429" / "Try again in" 매칭 | 메시지 시간 파싱 → sleep → 재시도             | 60s 이상 대기                 |
| 모델 daily/billing 한도 | "exceeded" / "billing" / "credit"          | 즉시 critical                                 | (즉시)                        |
| 컨텍스트 ≥ 60%          | model footer token 추출                    | persistent: `/compact` 전송                   | 핵심 산출물 손실 위험 시 fork |
| 컨텍스트 ≥ 85%          | 동일                                       | 강제 fork (새 pane spawn + 부트스트랩 재주입) | 보고만 (작업 이어감)          |
| self-verify 2회 실패    | manifest 누적                              | 페인에 재요청                                 | 2회째 실패                    |
| 2차 검증 2회 실패       | manifest 누적                              | 차이 보여주고 재시도                          | 2회째 실패                    |
| 통합 테스트 3회 실패    | self-verify 결과 누적                      | dev pane에 실패 로그 재투입                   | 3회째 실패                    |
| 사용자 강제 중단        | orchestrator 인터럽트                      | manifest 모든 stage status = paused           | 보고                          |

### 9.2 작업 재개 (resume)

orchestrator 호출 시 첫 단계:

```
0'. 사전 점검 + resume 감지
   ├─ feature_slug 인자 또는 task description hash 로 .cmux-orchestrator/<slug>/manifest.json 검사
   ├─ 존재 + 일부 stage가 done/paused 면 → resume mode
   │   ├─ 사용자 한 줄 보고: "이전 manifest 발견 (slug=X, plan/test-scenario done). 이어가시겠습니까?" — critical
   │   ├─ done 인 stage skip
   │   ├─ paused/failed stage 부터 재spawn
   │   └─ persistent pane (plan/design/review)이 cmux tree 에 살아있으면 재사용,
   │       죽었으면 새 spawn + 부트스트랩에 "이미 작성한 산출물 읽고 이어가라" 명시
   └─ 없으면 신규 워크플로우
```

명시적 호출: `--resume [slug]` 또는 자연어 "X 작업 재개". slug 없으면 `.cmux-orchestrator/` 스캔 후 사용자 선택.

## 10. 슬래시 명령 + 트리거

### 10.1 슬래시 명령 — `commands/cmux-orchestrate.md`

```markdown
---
description: cmux 위에서 plan/design/test/dev/review 페인을 자동 오케스트레이션해 작업 수행
---

cmux-orchestrator skill을 발동하여 사용자 요청을 multi-pane 워크플로우로 처리한다.

## 인자

- 인자 없음: 마지막 사용자 메시지를 task description으로 사용
- `--resume [slug]`: 재개 모드. slug 없으면 .cmux-orchestrator/ 스캔 후 선택
- `--here`: 현재 cmux workspace에 페인 추가 (기본: 새 workspace)

## 호출

1. ~/.claude/skills/cmux-orchestrator/SKILL.md 워크플로우 따름
2. 첫 단계: 사전 점검 → workspace 부트스트랩 → plan
3. critical decision 만 사용자 보고, 그 외 자동 진행
```

### 10.2 자연어 트리거 — SKILL.md frontmatter description

```yaml
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
```

## 11. Evals

### 11.1 트리거 평가 (description optimization 용)

```json
[
  {
    "query": "feature/startup-api-bulk 에서 신청서 폼이랑 검증 로직 한 번에 만들어줘. plan, test, 구현, 리뷰 다 거쳐서.",
    "should_trigger": true
  },
  {
    "query": "claude 랑 codex 같이 띄워서 이 PR 작업해",
    "should_trigger": true
  },
  {
    "query": "여러 역할로 나눠서 결제 모듈 한 번에 만들어줘",
    "should_trigger": true
  },
  {
    "query": "오케스트레이션 한 번 해줘 — 회원 가입 플로우 전체",
    "should_trigger": true
  },
  {
    "query": "이 한 줄만 고쳐줘 — userName -> user_name",
    "should_trigger": false
  },
  { "query": "이 함수 어떻게 동작해?", "should_trigger": false },
  {
    "query": "옆 페인 codex 한테 이거 한 번 봐달라고 해줘",
    "should_trigger": false
  },
  {
    "query": "dispatch parallel agents 로 테스트 3개 동시에 고쳐줘",
    "should_trigger": false
  }
]
```

### 11.2 동작 평가 (워크플로우 정확도)

```json
{
  "skill_name": "cmux-orchestrator",
  "evals": [
    {
      "id": 1,
      "name": "bugfix-no-ui",
      "prompt": "src/util/parsePhone.ts 의 한국 번호 파싱 버그 수정. 010-1234-5678 같은 표준 포맷이 fail. AC 정의 → RED 테스트 → fix → review 거쳐서.",
      "expected_output": "manifest.json 에 plan/test-code/dev/review 4단계 done, 06-review.md 통과, AC ≥ 1 ✓"
    },
    {
      "id": 2,
      "name": "new-feature-with-figma",
      "prompt": "Figma frame X 기반 신청서 폼 구현. design-system 컴포넌트 사용. plan-design-test-dev-review 풀 파이프라인.",
      "expected_output": "07-design-verify.md match_status=pass 또는 partial(이슈 ≤ 2), 모든 AC ✓"
    },
    {
      "id": 3,
      "name": "resume",
      "prompt": "(eval-1 의 manifest 가 plan done, test-code paused 상태에서) 재개해줘",
      "expected_output": "plan skip, test-code 부터 이어감, 최종 manifest done"
    }
  ]
}
```

자동 검증은 multi-pane + 외부 환경 의존성으로 어려움 → 초기는 사용자 검토 기반 (manifest + 산출물 비교), eval-viewer로 시각화.

## 12. Open Questions / Future

명시적으로 미해결인 항목:

- **Visualization command 자동 감지** — 현재 `manifest.visualization_command` 를 사용자가 명시하도록 함. `package.json` 의 scripts 자동 감지(`pnpm storybook`, `pnpm dev`) 로 디폴트 채우기 검토.
- **Codex 의 Figma MCP 지원** — 2026-04 시점 codex 가 Figma MCP를 들고 있는지 미검증. 현재는 design pane은 Claude로 고정. codex 가 Figma 지원되면 모델 라우팅 매트릭스 갱신.
- **Cross-workspace pane 통신** — 다른 cmux workspace 의 페인과 자문이 필요한 경우 (예: 다른 feature 의 review pane 참고). 현재는 같은 workspace 안만 지원. 필요 시 surface ref 에 workspace prefix 도입.
- **CI 통합** — orchestrator 자체를 CI 에서 비대화형으로 돌리는 시나리오. 현재 디자인은 사용자 cmux 환경 가정.
- **Telemetry / 비용 측정** — 한 작업이 사용한 모델 토큰/시간 합산 manifest 에 기록할지. 운영 시점 결정.

## 13. 작성 후 다음 단계

이 spec 승인 후:

1. `writing-plans` skill 호출하여 구현 계획 작성 (파일별, 단계별 to-do)
2. 계획 승인 후 skill 디렉토리 scaffolding → SKILL.md → references → scripts 순으로 구현
3. evals/evals.json 작성 → 트리거 description optimization 1회
4. 실 작업 1건 (예: QPLACE 의 작은 bugfix) 으로 dry-run, 실패 케이스 수집 → 패치
5. `description optimization loop` 를 사용 1주일 후 재실행

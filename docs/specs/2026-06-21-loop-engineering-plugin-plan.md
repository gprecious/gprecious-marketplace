# loop-engineering 플러그인 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** gprecious-marketplace에 `loop-engineering` 플러그인을 추가한다 — 반복 업무를 루프로 만들지 판정하고 5요소·가드레일·지표로 설계(`/loop-design`)·감사(`/loop-audit`)하는 거버넌스 레이어. 실행은 기존 엔진에 위임.

**Architecture:** 흐름의 단일 진실 공급원은 `skills/loop-engineering/references/{design-flow,audit-flow}.md`. Claude의 `commands/`와 SKILL은 그 flow를 가리키는 얇은 진입점이고, Codex 미러는 `commands/`가 없으므로 SKILL이 flow를 직접 실행한다. 루프 산출물(spec·registry·evidence)은 소비 repo의 `docs/loops/`에 파일로 커밋(control plane 기본값), GitHub Issue·Slack은 어댑터.

**Tech Stack:** Claude Code / Codex 플러그인 (markdown skill + slash commands), Python(검증 스크립트 `scripts/dual-tree-check.py`), git/gh.

## Global Constraints

- **dual-tree HARD RULE**: 플러그인은 `claude-plugins/loop-engineering/`(Claude)와 `.agents/plugins/plugins/loop-engineering/`(Codex) 양쪽에 존재. 내용 변경 시 양쪽 갱신 + 두 plugin.json `version` 동시 bump.
- **Codex 미러는 `skills/`만** — `commands/`는 Claude 전용. slash 명령 로직을 commands에만 두지 말고 `references/*-flow.md`에 둘 것.
- **카탈로그 2곳 등록**: `.claude-plugin/marketplace.json`(Claude SoT) + `.agents/plugins/marketplace.json`(Codex).
- **push 게이트**: `python3 scripts/dual-tree-check.py` → `OK: 버전 skew 없음` 확인 후에만 push.
- **owner 확인**: push 전 `gh auth status` + `git remote -v` → `gprecious` 계정.
- **완료 정의**: commit이 아니라 `git push origin <branch>` 까지. `git status -sb`에 `[ahead N]` 없어야 함.
- **plugin.json 금지 키**: `commands`/`agents`/`skills`(auto-discovery), `features`/`requiredEnvVars`/`optionalEnvVars`. (Codex plugin.json은 예외적으로 `skills: "./skills/"` + `interface` 블록 사용 — 기존 goalcraft codex 매니페스트 형식 따름.)
- **버전 시작값**: `0.1.0`.
- **control plane 기본 산출 경로**: 소비 repo의 `docs/loops/`.
- **루프 5요소**: trigger · state · verification · human gate · stop condition.
- **가드레일 7종**: max-iteration · max-wall-clock · token/cost budget · no-progress stop · worktree 격리 · evidence log · rollback path.
- **성공 지표 6종**: first-pass closure · rework count · review time · failure catch rate · no-op precision · cost per useful finding.
- **설계 출처**: `docs/specs/2026-06-21-loop-engineering-plugin-design.md` (이 plan의 상위 spec).

---

## 파일 구조 (생성 대상)

```
claude-plugins/loop-engineering/
├── .claude-plugin/plugin.json
├── README.md
├── commands/
│   ├── loop-design.md                 # thin → references/design-flow.md
│   └── loop-audit.md                  # thin → references/audit-flow.md
└── skills/loop-engineering/
    ├── SKILL.md
    └── references/
        ├── principles.md              # 정의·오해교정·triage 4기준·human gate
        ├── guardrails-and-metrics.md  # 가드레일 7종 + 지표 6종
        ├── backend-mapping.md         # 실행엔진 선택 결정표
        ├── control-plane-adapters.md  # file(기본)/github-issue/slack-relay
        ├── catalog.md                 # 우리 맥락 루프 레시피
        ├── design-flow.md             # /loop-design 캐노니컬 절차
        ├── audit-flow.md              # /loop-audit 캐노니컬 절차
        └── templates/
            ├── loop-spec.md
            └── registry.md

.agents/plugins/plugins/loop-engineering/      # Codex 미러
├── .codex-plugin/plugin.json
└── skills/loop-engineering/   (Claude skills/ 트리 미러)
```

수정 대상:

- `.claude-plugin/marketplace.json` — plugins 배열에 1개 추가
- `.agents/plugins/marketplace.json` — plugins 배열에 1개 추가
- `README.md` — 플러그인 표에 1행 추가

---

### Task 1: 브랜치 + 설계문서 커밋 + 플러그인 매니페스트 + README 스켈레톤

**Files:**

- Commit: `docs/specs/2026-06-21-loop-engineering-plugin-design.md` (이미 작성됨)
- Commit: `docs/specs/2026-06-21-loop-engineering-plugin-plan.md` (이 문서)
- Create: `claude-plugins/loop-engineering/.claude-plugin/plugin.json`
- Create: `claude-plugins/loop-engineering/README.md`

**Interfaces:**

- Produces: 플러그인 `name="loop-engineering"`, `version="0.1.0"`. 이후 모든 Task가 이 디렉토리 안에 파일을 추가.

- [ ] **Step 1: main 기준 깨끗한 브랜치 생성 (다른 작업 변경 미접촉)**

현재 marketplace는 `feat/devsweep-license-monetization` 브랜치에 session-journal 관련 uncommitted 변경이 있다. 이를 건드리지 않고 새 브랜치를 만든다.

```bash
cd /Users/taejin/Documents/dev/gprecious-marketplace
git stash push -u -m "wip-devsweep-before-loop-engineering" -- .agents/plugins/  # 다른 작업 변경 임시 보관
git fetch origin
git checkout -b feature/loop-engineering-plugin origin/main
```

Expected: 새 브랜치 체크아웃, `docs/specs/2026-06-21-loop-engineering-plugin-design.md`는 untracked로 따라옴(origin/main에 없음). stash로 보관한 devsweep 변경은 워킹트리에서 빠짐.

> 주의: stash가 의도대로 분리되는지 `git status -sb`로 확인. devsweep 변경이 본 브랜치에 섞이면 안 됨. 만약 stash 분리가 위험하면 사용자에게 알리고 대안(devsweep 위에서 브랜치) 협의.

- [ ] **Step 2: plugin.json 작성**

Create `claude-plugins/loop-engineering/.claude-plugin/plugin.json`:

```json
{
  "name": "loop-engineering",
  "version": "0.1.0",
  "description": "반복 업무를 루프로 만들지 판정하고 trigger·state·verification·human-gate·stop의 5요소 + 가드레일 7종 + 지표 6종으로 설계·감사하는 거버넌스 레이어. 실행은 직접 하지 않고 기존 엔진(herdr·/loop·Cron·Workflow·Codex Automations)에 매핑. /loop-design 으로 루프 스펙 생성, /loop-audit 으로 no-op precision·드리프트 점검. control plane 기본값은 repo 내 docs/loops/ 파일, GitHub Issue·Slack은 어댑터.",
  "author": {
    "name": "gprecious",
    "email": "gprecious@users.noreply.github.com"
  },
  "keywords": [
    "loop-engineering",
    "agent-loops",
    "automation",
    "governance",
    "ops",
    "claude-code",
    "codex"
  ]
}
```

- [ ] **Step 3: plugin README 작성**

Create `claude-plugins/loop-engineering/README.md`:

```markdown
# loop-engineering

반복 업무를 **루프로 만들지 판정**하고, `trigger · state · verification · human gate · stop`의
5요소 + 가드레일 7종 + 지표 6종으로 **설계·등록·감사**하는 거버넌스 레이어.
**실행은 직접 하지 않는다** — herdr·`/loop`·`/goal`·Cron·Workflow·Codex Automations 등
기존 엔진에 매핑만 한다.

## 명령

- `/loop-design <반복 업무 설명>` — triage(4기준) → 통과 시 5요소·가드레일·backend·control plane을
  대화로 설계 → `docs/loops/<loop-name>/spec.md` 생성 + `registry.md` 등록.
- `/loop-audit [registry 경로]` — 등록 루프의 spec 완결성·지표·드리프트·no-op precision 점검 →
  `docs/loops/audit-<date>.md`.

자동 발동: "이 일을 자동화/반복하고 싶어", "루프로 돌리고 싶어" 류 발화 시 skill이 떠서 위 명령으로 라우팅.

## 철학

Loop engineering은 제품 양산 자동화가 아니라, 이미 하네스가 있는 반복 업무를 검증 가능한 폐쇄
루프로 감싸는 **운영 설계**다. 분석은 LLM에게, **결정(진행 여부·scope 대비 가치·리스크)은 사람에게**.
큰 fleet이 아니라 검증 가능한 작은 루프 1~3개부터.

## control plane

기본은 소비 repo의 `docs/loops/` 파일(git 커밋). `references/control-plane-adapters.md`로
GitHub Issue·Slack-relay 미러링 선택 가능.
```

- [ ] **Step 4: plugin.json 유효성 검증**

Run:

```bash
python3 -c "import json; json.load(open('claude-plugins/loop-engineering/.claude-plugin/plugin.json')); print('valid')"
```

Expected: `valid`

- [ ] **Step 5: Commit**

```bash
git add docs/specs/2026-06-21-loop-engineering-plugin-design.md docs/specs/2026-06-21-loop-engineering-plugin-plan.md claude-plugins/loop-engineering/.claude-plugin/plugin.json claude-plugins/loop-engineering/README.md
git commit -m "feat(loop-engineering): 설계문서·plan·플러그인 매니페스트 스캐폴드"
```

---

### Task 2: 독트린 references — principles.md + guardrails-and-metrics.md

**Files:**

- Create: `claude-plugins/loop-engineering/skills/loop-engineering/references/principles.md`
- Create: `claude-plugins/loop-engineering/skills/loop-engineering/references/guardrails-and-metrics.md`

**Interfaces:**

- Produces: triage 4기준, human gate 원칙(principles.md); 가드레일 7종·지표 6종 정의(guardrails-and-metrics.md). design-flow/audit-flow가 이를 인용.

- [ ] **Step 1: principles.md 작성**

Create `.../references/principles.md` (출처: 설계 spec §1, FuelAI 리포트):

```markdown
# Loop Engineering 원칙

## 정의

이미 하네스가 있는 반복 업무를 **trigger · state · verification · human gate · stop condition**으로
감싸는 운영 설계층. prompt를 잘 쓰는 일이 아니라, agent가 다시 시도할 수 있는 **환경·검증·종료조건·
상태저장소**를 설계하는 일.

## 가장 큰 오해 (반드시 교정)

루프 엔지니어링은 **제품 전체를 자동 양산하는 공장이 아니다.** 제품에는 사람의 취향·우선순위·
risk appetite이 들어가므로, human gate 없이 모든 단계를 자동화하면 scope 대비 리스크를 판단하지
못한다. 많은 작업은 24/7 fleet이 아니라 single session + 좋은 prompt의 **solo loop**로 충분하다.

## 도입 판정 4기준 (triage)

후보 업무가 아래 4개를 **모두** 만족할 때만 루프로 만든다.

| 기준           | 질문                               | 탈락 예시          |
| -------------- | ---------------------------------- | ------------------ |
| `repetitive`   | 반복적으로 발생하는가?             | 1회성 마이그레이션 |
| `reviewable`   | 결과를 사람이 검토 가능한가?       | 검증 불가능한 창작 |
| `valuable`     | 가치 > token/time cost 인가?       | 月 1회·5분 수작업  |
| `bounded-risk` | 되돌릴 수 있고 폭발 범위가 좁은가? | prod DB 직접 변경  |

하나라도 불만족 → 루프 부적합. 단발 작업이면 goalcraft로, 큰 리스크면 사람이 직접.

## Human Gate 원칙

- **분석은 LLM에게, 결정은 사람에게.** issue 분석·코드베이스 조사·metadata 작성은 맡기되,
  진행 여부·scope 대비 가치·리스크 판단은 사람이 요약 리포트를 보고 결정한다.
- 모든 단계가 아니라 **scope가 넓거나 / 배포 영향이 크거나 / 주관적 product taste가 필요한** 지점에만.
- 반대로 no-op report·docs drift 확인·"에러 없음" 보고처럼 **결과가 좁고 되돌리기 쉬운** 루프는
  자동 종료 허용.
- **human gate 전에는 코드/문서 변경을 만들지 않는다** (진행 결정 전 변경 = 불필요한 diff).

## done criteria

objective metric에 가까울수록 좋다. 주관적 기준이면 반드시 **rubric + independent checker +
sample set + pass/fail threshold + hard cap**을 붙인다. "만족할 때까지"는 금지.
핵심 질문: _"What does done mean, and how will it check?"_
```

- [ ] **Step 2: guardrails-and-metrics.md 작성**

Create `.../references/guardrails-and-metrics.md`:

```markdown
# 가드레일 & 지표

## 가드레일 7종 (모든 루프 spec에 필수, 빈칸 불가)

| 가드레일          | 의미                      | 예시 값             |
| ----------------- | ------------------------- | ------------------- |
| max-iteration     | 최대 반복 횟수            | 5                   |
| max-wall-clock    | 벽시계 상한               | 30m                 |
| token/cost budget | 토큰·비용 예산            | $2 / run            |
| no-progress stop  | 진전 없으면 중단          | 2회 연속 변화 없음  |
| worktree 격리     | 코드 루프는 격리 checkout | git worktree        |
| evidence log      | 실행 증거 기록            | `evidence/<run>.md` |
| rollback path     | 되돌리기 경로             | revert PR / 미적용  |

주관적 목표 보강: rubric · independent checker · sample set · pass/fail threshold · hard cap.

## 성공 지표 6종 (agent 실행량 ❌)

루프의 성공은 "몇 번 돌았나"가 아니다.

| 지표                    | 정의                                                         |
| ----------------------- | ------------------------------------------------------------ |
| first-pass closure      | 첫 통과로 완료된 비율                                        |
| rework count            | 재작업 횟수                                                  |
| review time             | 사람 검토 소요                                               |
| failure catch rate      | 실패를 잡아낸 비율                                           |
| **no-op precision**     | "변경 없음"을 신뢰성 있게 보고하는 정확도 (false positive ↓) |
| cost per useful finding | 유용한 발견 1건당 비용                                       |

ops 루프(매일 돌아도 대부분 no-op)는 특히 **no-op precision**이 핵심. "변경 없음을 신뢰성 있게
보고하는 것"도 제품 기능처럼 취급한다.

## 도입 단계 (stage)

spec에 현재 stage를 표기한다.

| stage       | 의미              | 게이트                                      |
| ----------- | ----------------- | ------------------------------------------- |
| `draft`     | 설계만 됨         | 미실행                                      |
| `dry-run`   | 수동 트리거만     | false positive·runaway 관찰 중              |
| `scheduled` | 스케줄/inbox 연결 | no-op precision·useful finding rate 안정 후 |
```

- [ ] **Step 3: 파일 존재·구조 검증**

Run:

```bash
test -f claude-plugins/loop-engineering/skills/loop-engineering/references/principles.md && \
test -f claude-plugins/loop-engineering/skills/loop-engineering/references/guardrails-and-metrics.md && \
grep -q "도입 판정 4기준" claude-plugins/loop-engineering/skills/loop-engineering/references/principles.md && \
grep -q "no-op precision" claude-plugins/loop-engineering/skills/loop-engineering/references/guardrails-and-metrics.md && echo OK
```

Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add claude-plugins/loop-engineering/skills/loop-engineering/references/principles.md claude-plugins/loop-engineering/skills/loop-engineering/references/guardrails-and-metrics.md
git commit -m "feat(loop-engineering): 독트린 references(원칙·가드레일·지표)"
```

---

### Task 3: 메커니즘 references — backend-mapping.md + control-plane-adapters.md

**Files:**

- Create: `.../references/backend-mapping.md`
- Create: `.../references/control-plane-adapters.md`

**Interfaces:**

- Produces: backend 결정표(어떤 실행엔진에 태울지), control plane 어댑터 3종. design-flow가 인용.

- [ ] **Step 1: backend-mapping.md 작성**

Create `.../references/backend-mapping.md`:

```markdown
# Backend 매핑 결정표

loop-engineering은 **실행하지 않는다.** 설계된 루프를 아래 엔진 중 하나에 태운다고 spec에 명시만 한다.

| 루프 성격                             | 권장 backend                              | 비고                                   |
| ------------------------------------- | ----------------------------------------- | -------------------------------------- |
| 단일 세션·명확한 stop·solo loop       | Claude Code `/loop` 또는 `/goal`          | 가장 단순                              |
| 정기 스케줄·백그라운드·findings inbox | Cron(launchd/systemd) / Codex Automations | no-op 자동완료 루프                    |
| 병렬 워커·역할 분리                   | herdr / cmux                              | maker-checker·manager-with-helpers     |
| 결정론적 fan-out + verify 파이프라인  | Workflow tool                             | dimension fan-out + adversarial verify |
| 상시 가용·watchdog·failover 필요      | prime-orchestrator                        | active-active 운영 루프                |

선택 규칙:

1. 사람 게이트가 매 사이클 필요 → 스케줄 금지, solo loop + 수동 트리거.
2. 결과가 좁고 되돌리기 쉬움 + 매일 점검 → Cron/Codex Automations, no-op 자동완료.
3. 한 사이클이 여러 독립 하위작업으로 쪼개짐 → Workflow 또는 herdr.
4. 다운타임 불가 → prime-orchestrator.

backend는 **1개만** 지정한다. 두 개 이상이면 루프를 분리한다.
```

- [ ] **Step 2: control-plane-adapters.md 작성**

Create `.../references/control-plane-adapters.md`:

````markdown
# Control Plane 어댑터

루프의 state·evidence·gate를 어디서 inspect 하는가. `spec.md` 형식은 동일하고, **미러링 대상만** 바꾼다.

| 어댑터          | state 위치                         | 언제                                                                    |
| --------------- | ---------------------------------- | ----------------------------------------------------------------------- |
| **file** (기본) | 소비 repo `docs/loops/` (git 커밋) | 제품 비종속·버전관리·최고 이식성. 항상 기본.                            |
| github-issue    | GitHub Issue (label/comment)       | intake→gate→ship이 PR과 직결될 때. owner=gprecious/qplace-company 확인. |
| slack-relay     | Slack 스레드 (prime-orchestrator)  | 사람 게이트가 빠른 응답 필요. 기존 relay 인프라 재사용.                 |

## file (기본) 레이아웃

```
docs/loops/
  registry.md                 # 등록 루프 목록 1행/루프
  <loop-name>/
    spec.md                   # 5요소·가드레일·지표·backend·gate
    evidence/<run-id>.md      # 실행 증거 (no-op report 포함)
```

## 어댑터는 미러일 뿐

file이 항상 진실 공급원(SoT). github-issue/slack-relay는 같은 spec을 사람이 보기 쉬운 곳에
**복제**하는 것. 어댑터를 켜도 `docs/loops/`는 계속 커밋한다.
````

- [ ] **Step 3: 검증**

Run:

```bash
grep -q "backend는 \*\*1개만\*\*" claude-plugins/loop-engineering/skills/loop-engineering/references/backend-mapping.md && \
grep -q "file이 항상 진실 공급원" claude-plugins/loop-engineering/skills/loop-engineering/references/control-plane-adapters.md && echo OK
```

Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add claude-plugins/loop-engineering/skills/loop-engineering/references/backend-mapping.md claude-plugins/loop-engineering/skills/loop-engineering/references/control-plane-adapters.md
git commit -m "feat(loop-engineering): 메커니즘 references(backend 매핑·control plane 어댑터)"
```

---

### Task 4: 산출 아티팩트 — templates/loop-spec.md + templates/registry.md + catalog.md

**Files:**

- Create: `.../references/templates/loop-spec.md`
- Create: `.../references/templates/registry.md`
- Create: `.../references/catalog.md`

**Interfaces:**

- Produces: `loop-spec.md` 템플릿(design-flow가 채워서 소비 repo에 복사), `registry.md` 템플릿, 카탈로그 6종 레시피.

- [ ] **Step 1: loop-spec.md 템플릿 작성**

Create `.../references/templates/loop-spec.md`:

```markdown
# Loop Spec: <loop-name>

- stage: draft | dry-run | scheduled
- owner: <사람>
- created: <YYYY-MM-DD>
- backend: <한 개만 — /loop, Cron, herdr, Workflow, Codex Automations, prime-orchestrator>
- control-plane: file | github-issue | slack-relay

## triage (도입 판정)

- repetitive: <근거>
- reviewable: <근거>
- valuable: <근거>
- bounded-risk: <근거>
- 판정: PASS

## 5요소

- **trigger**: <ticket | schedule | event | human request — 구체적으로>
- **state**: <지속 상태 위치/형식>
- **verification**: <센서 — 실행 가능한 명령/체크. 예: `pnpm lint` exit 0, console 에러 0>
- **human gate**: <위치 + 무엇을 결정 — 또는 "없음(저위험 자동완료)">
- **stop condition**: <done criteria — objective 우선. 주관적이면 rubric+threshold>

## 가드레일 (7종 전부)

- max-iteration: <N>
- max-wall-clock: <시간>
- token/cost budget: <값>
- no-progress stop: <조건>
- worktree 격리: <yes/no + 방식>
- evidence log: <경로>
- rollback path: <경로>

## 지표 (추적 대상)

- first-pass closure / rework count / review time / failure catch rate / no-op precision /
  cost per useful finding 중 이 루프에 의미 있는 것 표시.

## 실행 메모

- 어떤 backend 명령으로 어떻게 트리거하는지 1~3줄.
```

- [ ] **Step 2: registry.md 템플릿 작성**

Create `.../references/templates/registry.md`:

```markdown
# Loop Registry

소비 repo의 모든 루프를 1행으로. `/loop-audit`이 이 표를 스캔한다.

| loop   | stage   | backend | control-plane | human gate | spec                     |
| ------ | ------- | ------- | ------------- | ---------- | ------------------------ |
| <name> | dry-run | /loop   | file          | 수정 PR 전 | [spec](./<name>/spec.md) |
```

- [ ] **Step 3: catalog.md 작성 (우리 맥락 루프 레시피)**

Create `.../references/catalog.md` (FuelAI Loop Library를 QPLACE/gprecious 맥락으로 번역):

```markdown
# 루프 카탈로그 (우리 맥락)

리서치의 Loop Library(FuelAI용 31개)를 그대로 쓰지 않고, QPLACE/gprecious 맥락으로 번역한
**검증 가능한 출발 템플릿**. 채택 여부·우선순위는 `/loop-design` triage와 사람 결정으로 정한다.

| 루프                    | trigger                           | verification(센서)                       | stop                   | backend           | human gate            |
| ----------------------- | --------------------------------- | ---------------------------------------- | ---------------------- | ----------------- | --------------------- |
| `preview-error-sweep`   | preview 배포 후 / 스케줄          | Chrome console·network 에러 0, smoke 200 | 에러 0 또는 issue 생성 | Cron / `/loop`    | 실제 수정 PR 전       |
| `migration-drift-check` | 스케줄 / 배포 전                  | beta PG 스키마 ↔ `src/migration/` diff   | drift 0 또는 리포트    | Codex Automations | drift 수동 적용 결정  |
| `docs-drift-sweep`      | 스케줄                            | CLAUDE.md/AGENTS.md ↔ 코드 일치          | 불일치 0 또는 리포트   | Cron              | 문서 수정 PR 전       |
| `e2e-healer`            | CI 실패 / vitest·Playwright trace | 테스트 재실행 GREEN                      | GREEN 또는 max-iter    | herdr / Workflow  | 구현 변경이 클 때     |
| `pr-review-loop`        | PR open                           | beomgu/api-cms 패턴·품질 리뷰어 통과     | 리뷰 통과              | Workflow          | merge 결정            |
| `lint-type-sweep`       | 스케줄                            | `pnpm lint` + `tsc` exit 0               | exit 0 또는 리포트     | Cron              | 없음(저위험 자동완료) |

각 레시피는 빈칸 없는 출발점이다. `/loop-design`은 사용자가 카탈로그 항목을 고르면 해당 행을
`loop-spec.md` 템플릿에 펼쳐 채운다.
```

- [ ] **Step 4: 검증**

Run:

```bash
for f in templates/loop-spec.md templates/registry.md catalog.md; do
  test -f "claude-plugins/loop-engineering/skills/loop-engineering/references/$f" || { echo "MISSING $f"; exit 1; }
done
grep -q "preview-error-sweep" claude-plugins/loop-engineering/skills/loop-engineering/references/catalog.md && \
grep -q "5요소" claude-plugins/loop-engineering/skills/loop-engineering/references/templates/loop-spec.md && echo OK
```

Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add claude-plugins/loop-engineering/skills/loop-engineering/references/templates claude-plugins/loop-engineering/skills/loop-engineering/references/catalog.md
git commit -m "feat(loop-engineering): 산출 아티팩트(spec·registry 템플릿·루프 카탈로그)"
```

---

### Task 5: 절차 references — design-flow.md + audit-flow.md (핵심)

**Files:**

- Create: `.../references/design-flow.md`
- Create: `.../references/audit-flow.md`

**Interfaces:**

- Consumes: principles.md(triage 4기준·human gate), guardrails-and-metrics.md(가드레일·지표·stage), backend-mapping.md, control-plane-adapters.md, templates/, catalog.md.
- Produces: 캐노니컬 절차. Claude commands·SKILL·Codex SKILL이 모두 이 두 파일을 가리킨다 (DRY 단일 진실 공급원).

- [ ] **Step 1: design-flow.md 작성**

Create `.../references/design-flow.md`:

```markdown
# /loop-design 절차 (캐노니컬)

입력: 반복 업무 설명($ARGUMENTS). 산출: 소비 repo `docs/loops/<loop-name>/spec.md` + `registry.md` 1행.
이 절차는 Claude `/loop-design` 명령, skill 자동발동, Codex skill이 공통으로 따른다.

## 0. 카탈로그 매칭

사용자 입력이 `references/catalog.md`의 한 행과 유사하면 그 레시피를 출발점으로 제안한다.

## 1. Triage (도입 판정) — human gate #1

`references/principles.md`의 4기준(repetitive·reviewable·valuable·bounded-risk)을 하나씩 묻고
근거를 받는다. 하나라도 불만족이면 **루프를 만들지 않고** 사유를 설명한다:

- 단발성 → goalcraft로 단발 prompt 안내
- 큰 리스크/되돌리기 어려움 → 사람이 직접 처리 권고
  4기준 PASS여야 다음으로 진행.

## 2. 5요소 설계 (대화형)

`templates/loop-spec.md`를 채운다. 각 요소를 한 번에 하나씩 묻는다:

1. **trigger** — ticket/schedule/event/human request 중 무엇이고 구체적 조건은?
2. **state** — 사이클 사이 무엇을 어디에 저장? (기본 file: `docs/loops/<name>/`)
3. **verification** — **실행 가능한 센서**여야 한다. "잘 됐는지 확인"이 아니라 `pnpm lint` exit 0,
   console 에러 0, 스크린샷 diff 같은 결정론적 명령. 없으면 만들 수 있는지 함께 설계.
4. **human gate** — 어디에 둘지. principles.md 기준(넓은 scope·배포 영향·product taste). 저위험이면 "없음".
5. **stop condition** — objective metric 우선. 주관적이면 rubric+independent checker+threshold+hard cap 강제.

## 3. 가드레일 7종 (빈칸 불가)

`guardrails-and-metrics.md`의 7종을 전부 값으로 채운다. 사용자가 모르면 보수적 기본값 제안
(max-iter 5, wall-clock 30m, no-progress 2회). 코드 변경 루프면 worktree 격리 yes 강제.

## 4. backend 매핑 (1개)

`backend-mapping.md` 결정표로 정확히 1개 backend 지정. 2개 이상 필요하면 루프를 쪼개라고 안내.

## 5. control plane

`control-plane-adapters.md`에서 택1. 기본 file. github-issue/slack-relay 선택 시에도 file은 유지.

## 6. 지표

루프에 의미 있는 지표(6종 중)를 표시. ops 루프면 no-op precision 필수 포함.

## 7. stage 지정

신규 루프는 `dry-run`으로 시작(스케줄 금지). no-op precision·useful finding rate 안정 후에만
`/loop-audit`이 `scheduled` 승격을 권고한다.

## 8. 산출물 쓰기 — human gate #2

완성된 spec을 사용자에게 **요약 제시**하고 승인받는다(진행 결정 전 변경 금지 원칙). 승인 후:

- 소비 repo가 어디인지 확인(현재 작업 repo. 모르면 묻는다).
- `docs/loops/<loop-name>/spec.md` 작성 (`templates/loop-spec.md` 채운 것).
- `docs/loops/registry.md` 없으면 `templates/registry.md`로 생성, 있으면 1행 추가.
- evidence 디렉토리 `docs/loops/<loop-name>/evidence/` 생성(.gitkeep).
- 커밋은 사용자 결정에 맡긴다(자동 push 금지).

## 출력 형식

끝에 다음을 요약: loop-name, stage=dry-run, backend, control-plane, 다음 행동(수동 드라이런 N회 후
/loop-audit).
```

- [ ] **Step 2: audit-flow.md 작성**

Create `.../references/audit-flow.md`:

```markdown
# /loop-audit 절차 (캐노니컬)

입력: registry 경로(기본 `docs/loops/registry.md`). 산출: `docs/loops/audit-<YYYY-MM-DD>.md`.
**읽기만 한다** — 코드/루프를 바꾸지 않는다. 결과가 없으면 no-op 리포트로 끝낸다.

## 1. 레지스트리 로드

registry.md를 읽어 등록 루프 목록을 만든다. 없으면 "등록된 루프 없음"으로 종료(no-op).

## 2. 루프별 점검

각 루프의 spec.md를 읽고:

- **완결성**: 5요소·가드레일 7종에 빈칸이 있으면 FLAG.
- **드리프트**: verification에 적힌 명령/경로, backend가 실제로 존재하는지 확인
  (예: `pnpm lint` 스크립트 존재, 참조 파일 존재). 없으면 FLAG.
- **stage 적정성**: `scheduled`인데 evidence가 빈약하거나 no-op precision 근거 없으면 FLAG(강등 권고).

## 3. 지표 집계

각 루프 evidence/ 로그에서 지표(`guardrails-and-metrics.md` 6종)를 집계 가능하면 집계.
특히 ops 루프는 **no-op precision**(전체 실행 중 정확한 "변경 없음" 비율)을 보고. 데이터 부족이면 명시.

## 4. 승격 판정

`dry-run` 루프 중 no-op precision·useful finding rate가 안정적이면 **`scheduled` 승격 후보**로
표시하고, 적합 backend 연결을 권고(backend-mapping.md). 단 승격은 사람 결정(human gate).

## 5. 리포트 작성

`docs/loops/audit-<date>.md`에:

- 요약(루프 수, FLAG 수, 승격 후보 수)
- 루프별 PASS/FLAG + 사유
- 액션 아이템(빈칸 채우기·드리프트 수정·승격/강등)
  변경 사항이 하나도 없으면 "all clear (no-op)"로 끝낸다 — no-op 보고도 정상 산출물이다.
```

- [ ] **Step 3: 검증**

Run:

```bash
grep -q "human gate #1" claude-plugins/loop-engineering/skills/loop-engineering/references/design-flow.md && \
grep -q "실행 가능한 센서" claude-plugins/loop-engineering/skills/loop-engineering/references/design-flow.md && \
grep -q "읽기만 한다" claude-plugins/loop-engineering/skills/loop-engineering/references/audit-flow.md && \
grep -q "no-op" claude-plugins/loop-engineering/skills/loop-engineering/references/audit-flow.md && echo OK
```

Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add claude-plugins/loop-engineering/skills/loop-engineering/references/design-flow.md claude-plugins/loop-engineering/skills/loop-engineering/references/audit-flow.md
git commit -m "feat(loop-engineering): 캐노니컬 절차(design-flow·audit-flow)"
```

---

### Task 6: 진입점 — SKILL.md + commands/loop-design.md + commands/loop-audit.md

**Files:**

- Create: `.../skills/loop-engineering/SKILL.md`
- Create: `claude-plugins/loop-engineering/commands/loop-design.md`
- Create: `claude-plugins/loop-engineering/commands/loop-audit.md`

**Interfaces:**

- Consumes: design-flow.md, audit-flow.md, principles.md (요약).
- Produces: 자동발동 skill + 2개 slash 명령. 모두 flow 파일을 가리키는 얇은 진입점.

- [ ] **Step 1: SKILL.md 작성**

Create `.../skills/loop-engineering/SKILL.md`:

```markdown
---
name: loop-engineering
description: Use when the user wants to turn a repetitive, reviewable task into a controlled agent loop — phrases like "이거 자동화/반복하고 싶어", "루프로 돌리고 싶어", "정기적으로 점검하게 해줘", "loop engineering", "agent loop 설계", or wants to audit existing loops ("루프 점검", "loop audit"). Designs a loop with trigger·state·verification·human-gate·stop + 7 guardrails + 6 metrics, maps it onto an existing engine (herdr/loop/Cron/Workflow/Codex Automations), and writes a spec to docs/loops/. Does NOT execute loops itself and is NOT for one-off prompts (use goalcraft) or multi-agent run orchestration (use herdr/cmux).
---

# loop-engineering

반복 업무를 **루프로 만들지 판정**하고 5요소·가드레일·지표로 **설계·감사**하는 거버넌스 레이어.
**실행은 하지 않는다** — 기존 엔진에 매핑만 한다.

## 핵심 원칙 (요약, 전문은 references/principles.md)

- 제품 양산 자동화 ❌. 이미 하네스 있는 반복 업무를 검증 가능한 폐쇄 루프로 감싸는 운영 설계.
- **분석은 LLM, 결정은 사람.** human gate는 넓은 scope·배포 영향·product taste 지점에만.
- 큰 fleet ❌, 검증 가능한 작은 루프 1~3개부터. 신규 루프는 `dry-run`으로 시작.

## 라우팅

사용자 의도에 따라 아래 절차를 따른다. (Claude는 `/loop-design`·`/loop-audit` 명령도 제공하지만,
명령 없이 발동했거나 Codex라면 아래 flow를 직접 실행한다.)

- **루프 설계** (반복 업무를 루프로 만들고 싶음) → `references/design-flow.md`를 읽고 그대로 수행.
- **루프 감사** (등록된 루프 점검) → `references/audit-flow.md`를 읽고 그대로 수행.

## 참조 (필요 시 읽기)

- `references/principles.md` — 정의·오해교정·triage 4기준·human gate
- `references/guardrails-and-metrics.md` — 가드레일 7종·지표 6종·stage
- `references/backend-mapping.md` — 실행엔진 선택
- `references/control-plane-adapters.md` — file/github-issue/slack-relay
- `references/catalog.md` — 우리 맥락 루프 레시피
- `references/templates/` — loop-spec·registry 템플릿

## 경계

- 단발 prompt 최적화 → goalcraft.
- 실제 병렬 실행/워커 spawn → herdr·cmux.
- 이 skill은 설계·감사·문서화까지만. 실행 트리거는 사람이 backend 명령으로 한다.
```

- [ ] **Step 2: commands/loop-design.md 작성 (얇은 wrapper)**

Create `claude-plugins/loop-engineering/commands/loop-design.md`:

```markdown
---
description: 반복 업무를 루프로 만들지 판정하고 5요소·가드레일·backend·control plane으로 설계해 docs/loops/에 spec 생성
---

`${CLAUDE_PLUGIN_ROOT}/skills/loop-engineering/references/design-flow.md`를 읽고, 그 절차를
처음부터 끝까지 따라 다음 반복 업무를 루프로 설계하라. triage 4기준을 먼저 통과시키고,
통과하면 5요소·가드레일 7종·backend 1개·control plane을 대화로 채운 뒤 사용자 승인을 받고
소비 repo의 `docs/loops/<loop-name>/spec.md` + `registry.md`를 작성하라. 실행은 하지 말 것.

대상 업무: $ARGUMENTS
```

- [ ] **Step 3: commands/loop-audit.md 작성 (얇은 wrapper)**

Create `claude-plugins/loop-engineering/commands/loop-audit.md`:

```markdown
---
description: 등록된 루프의 spec 완결성·드리프트·지표·no-op precision을 점검해 audit 리포트 생성 (읽기 전용)
---

`${CLAUDE_PLUGIN_ROOT}/skills/loop-engineering/references/audit-flow.md`를 읽고, 그 절차를
따라 루프 레지스트리를 감사하라. 코드/루프를 바꾸지 말고 읽기만 하며, 결과가 없으면 no-op
리포트로 끝내라. 결과는 `docs/loops/audit-<오늘 날짜>.md`에 쓴다.

registry 경로(생략 시 docs/loops/registry.md): $ARGUMENTS
```

- [ ] **Step 4: SKILL frontmatter·명령 검증**

Run:

```bash
head -3 claude-plugins/loop-engineering/skills/loop-engineering/SKILL.md | grep -q "name: loop-engineering" && \
grep -q "design-flow.md" claude-plugins/loop-engineering/commands/loop-design.md && \
grep -q "audit-flow.md" claude-plugins/loop-engineering/commands/loop-audit.md && echo OK
```

Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add claude-plugins/loop-engineering/skills/loop-engineering/SKILL.md claude-plugins/loop-engineering/commands
git commit -m "feat(loop-engineering): SKILL 자동발동 + /loop-design·/loop-audit 명령"
```

---

### Task 7: Codex dual-tree 미러

**Files:**

- Create: `.agents/plugins/plugins/loop-engineering/.codex-plugin/plugin.json`
- Create: `.agents/plugins/plugins/loop-engineering/skills/loop-engineering/` (Claude skills 트리 미러)

**Interfaces:**

- Consumes: Task 2~6의 `claude-plugins/loop-engineering/skills/` 전체.
- Produces: Codex 런타임용 미러. commands는 미러 안 함(Codex는 skill만). SKILL이 flow를 직접 실행.

- [ ] **Step 1: skills 트리 복사**

Run:

```bash
mkdir -p .agents/plugins/plugins/loop-engineering/.codex-plugin
cp -R claude-plugins/loop-engineering/skills .agents/plugins/plugins/loop-engineering/skills
```

Expected: `.agents/plugins/plugins/loop-engineering/skills/loop-engineering/SKILL.md` + references 전체 복사됨.

> SKILL.md의 라우팅 블록은 이미 "Codex라면 flow를 직접 실행"을 명시하므로 그대로 호환. 별도 codex 전용 블록 불필요. (commands/는 의도적으로 미러하지 않음 — dual-tree 비대칭이지만 의도된 것.)

- [ ] **Step 2: Codex plugin.json 작성 (interface 블록 포함, goalcraft 형식)**

Create `.agents/plugins/plugins/loop-engineering/.codex-plugin/plugin.json`:

```json
{
  "name": "loop-engineering",
  "version": "0.1.0",
  "description": "Design and audit controlled agent loops — judge if a repetitive task should be a loop, then spec it with trigger·state·verification·human-gate·stop + 7 guardrails + 6 metrics, mapping execution onto existing engines. Does not run loops itself.",
  "author": {
    "name": "gprecious",
    "email": "gprecious@users.noreply.github.com",
    "url": "https://github.com/gprecious"
  },
  "repository": "https://github.com/gprecious/gprecious-marketplace",
  "keywords": [
    "loop-engineering",
    "agent-loops",
    "automation",
    "governance",
    "ops",
    "claude-code",
    "codex"
  ],
  "skills": "./skills/",
  "interface": {
    "displayName": "Loop Engineering",
    "shortDescription": "Design & audit controlled agent loops (not a runner).",
    "longDescription": "Turn a repetitive, reviewable task into a controlled agent loop. Judges loop-fitness with 4 criteria, designs trigger·state·verification·human-gate·stop with 7 guardrails and 6 metrics, maps it onto an existing engine (loop/Cron/herdr/Workflow/Automations), and writes a spec to docs/loops/. Audits registered loops for completeness, drift, and no-op precision. Does not execute loops.",
    "developerName": "gprecious",
    "category": "Productivity",
    "capabilities": ["Interactive"],
    "defaultPrompt": [
      "이 반복 업무를 통제된 루프로 설계해줘.",
      "Design a controlled loop for this recurring task.",
      "등록된 루프들을 감사해줘 (loop audit)."
    ],
    "brandColor": "#0EA5E9"
  }
}
```

- [ ] **Step 3: 미러 동일성·유효성 검증**

Run:

```bash
python3 -c "import json; json.load(open('.agents/plugins/plugins/loop-engineering/.codex-plugin/plugin.json')); print('json ok')"
diff -r claude-plugins/loop-engineering/skills .agents/plugins/plugins/loop-engineering/skills && echo "skills mirror identical"
```

Expected: `json ok` 그리고 `skills mirror identical` (diff 출력 없음).

- [ ] **Step 4: Commit**

```bash
git add .agents/plugins/plugins/loop-engineering
git commit -m "feat(loop-engineering): Codex dual-tree 미러(skills + codex plugin.json)"
```

---

### Task 8: 카탈로그 등록 + README + push 게이트

**Files:**

- Modify: `.claude-plugin/marketplace.json`
- Modify: `.agents/plugins/marketplace.json`
- Modify: `README.md`

**Interfaces:**

- Consumes: 두 트리 + 두 plugin.json(version 0.1.0 동일).
- Produces: marketplace에서 설치 가능한 등록 상태.

- [ ] **Step 1: Claude 카탈로그 등록**

Modify `.claude-plugin/marketplace.json` — `plugins` 배열에 추가(다른 항목 형식과 동일, 알파벳/논리 순서상 적절한 위치):

```json
{
  "name": "loop-engineering",
  "description": "반복 업무를 루프로 만들지 판정하고 trigger·state·verification·human-gate·stop 5요소 + 가드레일 7종 + 지표 6종으로 설계(/loop-design)·감사(/loop-audit)하는 거버넌스 레이어. 실행은 기존 엔진(herdr·/loop·Cron·Workflow·Codex Automations)에 위임. control plane은 docs/loops/ 파일 기본 + GitHub/Slack 어댑터.",
  "source": "./claude-plugins/loop-engineering",
  "category": "productivity"
}
```

- [ ] **Step 2: Codex 카탈로그 등록**

Modify `.agents/plugins/marketplace.json` — `plugins` 배열에 추가:

```json
{
  "name": "loop-engineering",
  "source": {
    "source": "local",
    "path": "./.agents/plugins/plugins/loop-engineering"
  },
  "policy": {
    "installation": "AVAILABLE",
    "authentication": "ON_INSTALL"
  },
  "category": "Productivity"
}
```

- [ ] **Step 3: README 표에 1행 추가**

Modify `README.md` — "Claude Code 플러그인" 표에 추가:

```markdown
| loop-engineering | 반복 업무를 루프로 만들지 판정 + 5요소·가드레일·지표로 설계(/loop-design)·감사(/loop-audit)하는 거버넌스 레이어. 실행은 기존 엔진 위임, control plane은 docs/loops/ 파일 기본 | `claude-plugins/loop-engineering` |
```

- [ ] **Step 4: 두 카탈로그 JSON 유효성 + 버전 skew 게이트**

Run:

```bash
python3 -c "import json; json.load(open('.claude-plugin/marketplace.json')); json.load(open('.agents/plugins/marketplace.json')); print('catalogs valid')"
python3 scripts/dual-tree-check.py
```

Expected: `catalogs valid` 그리고 `OK: 버전 skew 없음` (FAIL/SKEW 나오면 plugin.json version 불일치 — 둘 다 0.1.0인지 확인 후 수정).

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json .agents/plugins/marketplace.json README.md
git commit -m "feat(loop-engineering): 양 카탈로그 등록 + README 표"
```

- [ ] **Step 6: owner 확인 후 push (HARD RULE)**

```bash
gh auth status && git remote -v   # gprecious 계정·origin 확인
git status -sb                     # ahead 개수 확인
git push -u origin feature/loop-engineering-plugin
```

Expected: push 성공. `git status -sb`에 `[ahead N]` 남지 않음.

> push는 공유 원격 변경 행위. push 직전 사용자에게 한 번 알린다(정상 종료 단계).

---

### Task 9: Dogfooding 검증 (실제 동작 확인)

**Files:**

- (검증 전용 — 산출물은 임시, 커밋하지 않거나 별도 예시로만)

**Interfaces:**

- Consumes: 설치된 loop-engineering 플러그인.

- [ ] **Step 1: 플러그인 설치/리로드**

Claude Code에서 marketplace 갱신 후 `loop-engineering`을 설치(또는 로컬 working clone이면 자동 인식). `/loop-design`·`/loop-audit`이 명령 목록에, `loop-engineering`이 skill 목록에 보이는지 확인.

Expected: 두 명령 + 1 skill 노출.

- [ ] **Step 2: 적합 케이스 — triage 통과 + spec 생성**

임시 디렉토리 또는 QPLACE repo에서:

```
/loop-design preview 배포 후 콘솔·네트워크 에러 점검
```

Expected: triage 4기준 통과 → 5요소·가드레일 7종·backend 1개·human gate가 **빈칸 없이** 채워진 요약 제시 → 승인 시 `docs/loops/preview-error-sweep/spec.md` + `registry.md` 생성. `preview-error-sweep`이 카탈로그에서 출발점으로 제안되는지도 확인.

- [ ] **Step 3: 부적합 케이스 — triage 탈락**

```
/loop-design 새 로고 색상 정하기
```

Expected: `reviewable`/`bounded` 기준에서 탈락 + "루프 부적합" 사유 안내(주관적 product taste → 사람 결정). spec을 만들지 않음.

- [ ] **Step 4: audit**

Step 2로 spec이 생긴 상태에서:

```
/loop-audit
```

Expected: registry 스캔 → `preview-error-sweep` PASS/FLAG + 지표 자리 + stage(dry-run) 보고. `docs/loops/audit-<date>.md` 생성. 코드 변경 없음(읽기 전용).

- [ ] **Step 5: 결과 보고**

dogfooding 관찰 결과(통과/실패, spec 빈칸 여부, triage 동작)를 사용자에게 요약 보고. 문제 발견 시 해당 Task로 돌아가 수정 후 version patch bump(양쪽) + dual-tree-check + push.

---

## Self-Review (작성자 체크 결과)

**1. Spec coverage** — 설계 spec 각 절 대응:

- §1 정의/문제 → Task 2 principles.md ✓
- §2 정체성/Non-goals → SKILL.md 경계 + README ✓
- §3.1 구성요소 → Task 6 ✓ / §3.2 두 커맨드 → Task 5(flow)+Task 6(wrapper) ✓
- §3.3 데이터 흐름 → design-flow/audit-flow ✓ / §3.4 어댑터 → Task 3 ✓ / §3.5 backend → Task 3 ✓
- §4 카탈로그 → Task 4 catalog.md ✓
- §5 가드레일·지표 → Task 2 guardrails-and-metrics.md ✓
- §6 로드맵(stage) → guardrails-and-metrics.md stage + design-flow §7 ✓
- §7 배포·동기 → Task 7·8 ✓
- §8 dogfooding → Task 9 ✓

**2. Placeholder scan** — 템플릿의 `<...>`는 사용자가 채울 자리(의도된 placeholder, 산출 템플릿). plan 자체엔 TBD/TODO 없음. ✓

**3. Type/이름 일관성** — 파일 경로·skill name(`loop-engineering`)·명령(`/loop-design`,`/loop-audit`)·flow 파일명(`design-flow.md`,`audit-flow.md`)·산출 경로(`docs/loops/`)가 전 Task에서 동일. version 0.1.0 양쪽 동일. ✓

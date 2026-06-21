# loop-engineering 플러그인 설계 (Design Spec)

- 작성일: 2026-06-21
- 대상 repo: `gprecious-marketplace`
- 상태: 설계 합의 완료, 구현 plan 대기
- 출처 리서치:
  - Notion: "Loop Engineering 실무 도입 가이드" (research-engine 산출물, slug `2026-06-20-loop-engineering-practical-adoption`)
  - FuelAI 리포트: <https://fuelai.flow-finders.com/ko/reports/loop-engineering-practical-adoption>

---

## 1. 배경과 문제 정의

### 1.1 Loop Engineering이란 (리서치 요약)

Loop engineering은 **제품 전체를 자동 양산하는 공장이 아니다.** 이미 하네스가 있는 반복
업무를 다음 5요소로 감싸는 **운영 설계층**이다.

| 요소               | 의미                                                                                 |
| ------------------ | ------------------------------------------------------------------------------------ |
| **trigger**        | 루프를 시작시키는 것 — ticket, schedule, event, human request                        |
| **state**          | 반복 사이를 잇는 지속 상태 (control plane)                                           |
| **verification**   | agent가 환경에서 ground truth를 읽는 센서 — test/build exit/lint/diff/screenshot/log |
| **human gate**     | 사람이 결정해야 하는 지점 — 진행 여부·scope 대비 가치·리스크·product taste           |
| **stop condition** | 종료 조건 — done criteria, max-iter, no-progress                                     |

핵심 통찰:

- prompt를 잘 쓰는 일이 아니라, **agent가 다시 시도할 수 있는 환경·검증·종료조건·상태저장소를
  설계**하는 일이다 (Addy Osmani: "사람이 prompting하는 자리에서 빠지고, 그 prompting을
  수행하는 시스템을 설계").
- **사람 게이트의 본질: 분석은 LLM에게 맡기고, 결정은 사람이 한다.** 모든 단계가 아니라
  scope가 넓거나, 배포 영향이 크거나, 주관적 product taste가 필요한 지점에만.
- done criteria가 objective metric에 가까울수록 좋고, 주관적 기준엔 별도 scorer/rubric/eval을
  붙여야 한다 (Nate Herk: "What does done mean, and then how will it check?").
- 도입은 큰 agent fleet이 아니라 **검증 가능한 작은 폐쇄 루프 1~3개**부터.

### 1.2 우리가 풀려는 문제

gprecious/QPLACE 환경은 **실행 엔진이 이미 충분하다** — herdr(병렬 워커), `/loop`, `/goal`,
ScheduleWakeup, CronCreate, Workflow, prime-orchestrator(active-active watchdog/failover),
Codex Automations, preview 자동배포, slack-relay control plane.

빠져 있는 것은 도구가 아니라 **운영 규율(governance layer)** 이다:

- 어떤 반복 업무를 루프로 만들지 **판정하는 기준**이 암묵적이다.
- 루프의 5요소·가드레일·지표가 **문서로 고정**되지 않아, 루프가 runaway 하거나 evidence 없이
  돈다.
- 루프 성공을 **agent 실행량**으로 착각한다 (옳은 지표는 first-pass closure·no-op precision 등).

→ 이 플러그인은 그 governance layer를 **재사용 가능한 자산**으로 만든다.

---

## 2. 정체성과 경계 (Scope)

> **loop-engineering**: 반복 업무를 루프로 만들지 **판정**하고, 5요소 + 가드레일 + 지표로
> **설계·등록·감사**하는 거버넌스 레이어. **실행은 직접 하지 않고** 기존 엔진에 매핑만 한다.

### 2.1 Non-goals (명시적으로 하지 않는 것)

- ❌ **자체 실행 러너를 만들지 않는다.** 스케줄링·반복 실행·워커 spawn은 herdr / `/loop` /
  Cron / Workflow / Codex Automations 가 한다. 이 플러그인은 "어떤 엔진에 어떻게 태울지"만
  설계 산출물에 적는다. (중복 실행엔진 금지 — 기존 8개 플러그인은 _실행기_, 이건 _설계·감사_.)
- ❌ 제품 종속 로직을 넣지 않는다. FuelAI의 `curation-quality-eval-loop` 같은 구체 루프는
  카탈로그의 *예시*일 뿐, 코드로 박지 않는다.
- ❌ 프롬프트 작성 자체는 goalcraft 영역. 이 플러그인은 goalcraft가 만든 prompt를 **루프의
  trigger/verification 안에 배치**하는 상위 설계를 담당한다 (보완 관계).

### 2.2 기존 플러그인과의 관계

| 플러그인        | 역할                    | loop-engineering 과의 관계           |
| --------------- | ----------------------- | ------------------------------------ |
| goalcraft       | 단발 prompt 최적화      | 루프의 한 step prompt를 만들 때 호출 |
| herdr           | 병렬 워커 실행          | 루프의 backend(병렬 worker-loop)     |
| cmux            | 멀티페인 오케스트레이션 | 루프의 backend(역할 분리 실행)       |
| session-journal | 세션 로그               | 루프 evidence의 보조 소스            |
| research-engine | 심층 리서치             | 루프 후보 발굴의 입력                |

---

## 3. 아키텍처

### 3.1 구성요소 (Command + Skill 혼합)

```
claude-plugins/loop-engineering/
├── .claude-plugin/plugin.json
├── README.md
├── commands/
│   ├── loop-design.md          # /loop-design <업무 설명>
│   └── loop-audit.md           # /loop-audit [registry 경로]
└── skills/loop-engineering/
    ├── SKILL.md                # 자동 발동 + 라우팅 + 원칙 요약
    └── references/
        ├── principles.md               # 정의·오해교정·도입판정 4기준·human gate
        ├── guardrails-and-metrics.md   # 가드레일 7종 + 성공지표 6종
        ├── catalog.md                  # 우리 맥락 루프 레시피 (복붙용)
        ├── control-plane-adapters.md   # file(기본)/github-issue/slack-relay
        ├── backend-mapping.md          # 어떤 실행엔진에 태울지 결정표
        └── templates/
            ├── loop-spec.md            # 5요소 스펙 템플릿
            └── registry.md             # 레지스트리 템플릿
```

- Codex 미러: `.agents/plugins/plugins/loop-engineering/` (dual-tree HARD RULE).

### 3.2 두 커맨드

#### `/loop-design <반복 업무 설명>`

대화형. 산출물은 **소비 repo 안의** `docs/loops/<loop-name>/spec.md`.

1. **Triage (도입 판정)** — 4기준으로 통과/탈락 판정:
   - `repetitive` — 반복적인가?
   - `reviewable` — 결과를 사람이 검토 가능한가?
   - `valuable` — 가치 > token/time cost 인가?
   - `bounded-risk` — 되돌릴 수 있고 폭발 범위가 좁은가?
   - 탈락 시: 왜 루프 부적합인지 알려주고 종료 (단발 작업이면 goalcraft 안내).
2. **5요소 설계** — trigger / state / verification / human gate / stop condition 을
   대화로 채움. 주관적 done이면 rubric/scorer/threshold 강제.
3. **가드레일 부착** — max-iter, wall-clock, cost budget, no-progress stop, worktree
   격리, evidence log, rollback path (7종 전부 채움, 빈칸 불가).
4. **backend 매핑** — `backend-mapping.md` 결정표로 실행엔진 1개 지정 (herdr / `/loop` /
   Cron / Workflow / Codex Automations / prime-orchestrator).
5. **control plane 선택** — file(기본) / github-issue / slack-relay 어댑터 중 택1.
6. **레지스트리 등록** — `docs/loops/registry.md` 에 1행 추가.

#### `/loop-audit [registry 경로]`

레지스트리를 스캔해 **거버넌스 리포트**를 만든다 (변경 없이 읽기만 → no-op 가능):

- 각 루프의 spec 완결성 (5요소·가드레일 빈칸 검출)
- 지표 추적: first-pass closure, rework count, review time, failure catch rate,
  **no-op precision**, cost per useful finding
- 드리프트: spec이 가리키는 verification command/backend가 실제로 존재하는지
- "스케줄 붙여도 되는 루프" vs "아직 수동 드라이런 단계인 루프" 분류
- 출력: `docs/loops/audit-<date>.md` (또는 stdout 요약)

### 3.3 데이터 흐름

```
반복 업무
   │  /loop-design
   ▼
[Triage 4기준] ──탈락──▶ goalcraft 안내 / 종료
   │ 통과
   ▼
[5요소 + 가드레일 + backend + control plane]
   │
   ▼
docs/loops/<name>/spec.md  +  registry.md 1행      ◀── file control plane (기본)
   │                                  │
   │ (어댑터 선택 시)                  │  /loop-audit
   ▼                                  ▼
github-issue / slack-relay 미러   [거버넌스 리포트: 지표·드리프트·no-op precision]
```

### 3.4 control plane 어댑터

같은 `spec.md`를 **어디에 미러링/inspect 할지**만 바꾼다. spec 형식은 동일.

| 어댑터          | state 위치                                  | 사용처                                 |
| --------------- | ------------------------------------------- | -------------------------------------- |
| **file** (기본) | repo `docs/loops/` (git 커밋)               | 제품 비종속, 버전관리, 가장 이식적     |
| github-issue    | qplace-company GitHub Issue (label/comment) | intake→gate→ship 흐름이 PR과 직결될 때 |
| slack-relay     | Slack 스레드 (기존 prime-orchestrator)      | 사람 개입·게이트가 빠른 응답 필요할 때 |

### 3.5 backend 매핑 결정표 (요지)

| 루프 성격                             | 권장 backend                     |
| ------------------------------------- | -------------------------------- |
| 단일 세션·명확한 stop·solo loop       | Claude Code `/loop` 또는 `/goal` |
| 정기 스케줄·백그라운드·findings inbox | Cron / Codex Automations         |
| 병렬 워커·역할 분리                   | herdr / cmux                     |
| 결정론적 fan-out + verify 파이프라인  | Workflow tool                    |
| 상시 가용·watchdog·failover 필요      | prime-orchestrator               |

---

## 4. 우리 맥락 루프 카탈로그 (catalog.md 초안)

리서치의 Loop Library(FuelAI용 31개)를 그대로 쓰지 않고, **QPLACE/gprecious 맥락으로 번역한
검증 가능한 후보**를 싣는다. 각 항목은 trigger·verification·stop·backend·human gate가 채워진
복붙용 스펙으로 제공.

| 루프 후보               | trigger                           | verification(센서)                       | human gate                    |
| ----------------------- | --------------------------------- | ---------------------------------------- | ----------------------------- |
| `preview-error-sweep`   | preview 배포 후 / 스케줄          | Chrome console·network 에러 0, smoke 200 | 실제 수정 PR 전               |
| `migration-drift-check` | 스케줄 / 배포 전                  | beta PG 스키마 ↔ `src/migration/` diff   | drift 수동 적용 결정          |
| `docs-drift-sweep`      | 스케줄                            | CLAUDE.md/AGENTS.md ↔ 실제 코드 일치     | 문서 수정 PR 전               |
| `e2e-healer`            | CI 실패 / vitest·Playwright trace | 테스트 재실행 GREEN                      | 구현 변경이 클 때             |
| `pr-review-loop`        | PR open                           | beomgu/api-cms 패턴·품질 리뷰어 통과     | merge 결정                    |
| `lint-type-sweep`       | 스케줄                            | `pnpm lint` + `tsc` exit 0               | (저위험, no-op 자동완료 허용) |

> 카탈로그는 "예시 + 출발 템플릿"이다. 실제 채택 여부·우선순위는 `/loop-design` triage와
> 사람 결정으로 정한다.

---

## 5. 가드레일과 지표 (guardrails-and-metrics.md)

### 5.1 가드레일 7종 (스펙에 전부 필수)

max-iteration · max-wall-clock · token/cost budget · no-progress stop · worktree 격리
· evidence log · rollback path.

주관적 목표는 "만족할 때까지" 금지 → rubric + independent checker + sample set +
pass/fail threshold + hard cap 부착.

### 5.2 성공 지표 6종 (agent 실행량 ❌)

first-pass closure · rework count · review time · failure catch rate ·
**no-op precision**(변경 없음을 신뢰성 있게 보고하는 정확도) · cost per useful finding.

---

## 6. 도입 로드맵 (플러그인이 안내하는 운영 순서)

리서치의 0~3주차 로드맵을 `/loop-design`·`/loop-audit`이 자연스럽게 강제한다:

- **0주차**: 후보를 4기준으로 1~3개로 컷 (`/loop-design` triage가 강제)
- **1주차**: input/state/stop/verification/evidence 고정 (spec.md가 빈칸 불허)
- **2주차**: schedule 없이 수동 트리거 드라이런 (spec에 `stage: dry-run` 표기)
- **3주차+**: no-op precision·useful finding rate 안정 시 schedule/inbox 연결
  (`/loop-audit`이 "스케줄 가능" 판정 후 backend 연결 권고)

---

## 7. 배포·동기 (gprecious-marketplace HARD RULES)

- dual-tree: `claude-plugins/loop-engineering/` + `.agents/plugins/plugins/loop-engineering/`
  양쪽 생성, 두 plugin.json `version` 동시 부여.
- 카탈로그 2곳 등록: `.claude-plugin/marketplace.json` + `.agents/plugins/marketplace.json`.
- README.md 표에 1행 추가.
- push 전 게이트: `python3 scripts/dual-tree-check.py` → `OK: 버전 skew 없음`.
- owner 확인: `gh auth status` + `git remote -v` → `gprecious` 계정.
- 작업 마무리 = `git push origin <branch>` 까지 (commit만으로 끝 아님).

---

## 8. 검증 (Testing / Dogfooding)

플러그인은 코드가 적고 대부분 prompt/skill이므로, 검증은 **dogfooding**으로 한다:

1. 설치 후 `/loop-design "preview 배포 후 에러 점검"` 실행 → triage 통과 →
   `preview-error-sweep/spec.md` 생성, 5요소·가드레일 7종·backend 1개·human gate가 빈칸 없이 채워지는지.
2. 일부러 부적합 업무("로고 색 정하기") 투입 → triage 탈락 + 사유 안내되는지.
3. `/loop-audit` 실행 → 위 spec의 완결성·지표 자리·드리프트 리포트가 나오는지.
4. dual-tree-check.py 통과 + 양쪽 marketplace.json에서 로드되는지.

---

## 9. 합의된 결정 사항 (브레인스토밍 결과)

1. 1차 목표 = 방법론 **플러그인 자산화** (gprecious-marketplace).
2. 경계 = **설계 + 거버넌스 레이어**, 실행은 기존 엔진 위임 (자체 러너 ❌).
3. control plane = **파일/git 기본 + GitHub/Slack 어댑터**.
4. 이름 = **loop-engineering**.
5. MVP = **/loop-design + /loop-audit 둘 다** (설계 + 감사 완결).

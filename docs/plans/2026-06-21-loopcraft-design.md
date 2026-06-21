# loopcraft 설계 (Design Spec)

- 작성일: 2026-06-21
- 대상 repo: `gprecious-marketplace`
- 상태: 설계 합의 완료, 구현 plan 대기
- 출처 리서치:
  - Claude Code 공식 — "Run prompts on a schedule" (`code.claude.com/docs/en/scheduled-tasks`)
  - `/loop` dynamic-mode 시스템 프롬프트 (Piebald-AI/claude-code-system-prompts)
  - Loop Library 44 레시피 (`signals.forwardfuture.ai/loop-library/`, fuelai.flow-finders.com 경유)
  - requesty "Loop Engineering" 블로그 (자율 루프 해부학·runaway 방지)
  - research-engine `/evolve`·`/bench`·`/dream` (3-way gate·single-trial 금지·hard-cap)
  - 마켓플레이스 인접 자산: `goalcraft`(단발 형제), `loop-engineering`(거버넌스), `ralph-loop`(completion-promise)

---

## 1. 정체성과 경계 (Scope)

> **loopcraft**: 반복 업무 요구사항을 Claude Code **`/loop` 용 프롬프트**로 변환하는 생성기.
> **goalcraft의 loop 형제** — goalcraft가 단발 goal 프롬프트를 만들듯, loopcraft는 반복 `/loop`
> 프롬프트를 만든다.

- **입력**: 반복 업무 설명 / 거친 요구사항 ("배포 후 에러 점검 계속 돌려줘", "CI 통과할 때까지 반복")
- **출력**: 복붙용 `/loop …` 명령 한 줄(+ 본문이 길면 `loop.md` 텍스트). **모드 분기·객관적
  종료조건·iteration ceiling이 박힌** 프롬프트.

### 1.1 3자 경계 (라우팅)

| 업무 성격                              | 담당                | loopcraft의 행동                                   |
| -------------------------------------- | ------------------- | -------------------------------------------------- |
| 단발 1회 실행                          | **goalcraft**       | "이건 단발" 판정 시 goalcraft 안내                 |
| 반복 `/loop` 프롬프트                  | **loopcraft** ←본 스킬 | 변환 수행                                        |
| "루프로 만들까?" + 5요소 설계·감사     | **loop-engineering**| 거버넌스 필요 시 안내; 역으로 `/loop-design`이 호출 |

`loop-engineering` design §2.1이 "프롬프트 작성 자체는 goalcraft 영역"이라며 비워둔 칸 중
**반복(`/loop`) 전용 칸**을 loopcraft가 정확히 메운다 (보완재, 이름·범위 충돌 없음).

### 1.2 Non-goals (명시적으로 하지 않는 것)

- ❌ **실행하지 않는다.** `/loop` 명령 텍스트를 만들 뿐, 루프를 돌리지 않는다.
- ❌ **backend 매핑·거버넌스 감사를 하지 않는다.** (loop-engineering `/loop-design`·`/loop-audit` 영역)
- ❌ **executor-adaptive 아니다.** `/loop`은 Claude Code 고유 기능 — Codex엔 `/loop`이 없다.
  loopcraft는 Claude Code 전용. (goalcraft가 양쪽을 다루는 것과 의도적으로 다름)
- ❌ 단발 goal 프롬프트는 goalcraft 영역.

---

## 2. 아키텍처 (goalcraft 동형)

```
claude-plugins/loopcraft/                      # Codex dual-tree 미러:
├── .claude-plugin/plugin.json                 #   .agents/plugins/plugins/loopcraft/
├── README.md                                  #     ├── .codex-plugin/plugin.json
└── skills/loopcraft/                          #     └── skills/loopcraft/SKILL.md (+references)
    ├── SKILL.md                  # 진입 + 워크플로 (≈8KB, goalcraft 규모)
    └── references/
        ├── loop-modes.md         # 3모드별 작성 프로필
        └── recipes.md            # 종료조건 패턴 + few-shot 시드
```

- dual-tree HARD RULE: 양쪽 트리 함께 생성, 두 `plugin.json` `version` 동시 부여.
- SKILL 본문은 의미 기준 reconcile (플랫폼 전용 블록 없으면 동일 내용).

---

## 3. SKILL.md 워크플로 (goalcraft Step 미러)

### Step 1 — 모드 판정 (1차 분기, `/loop` 실제 동작과 1:1 매핑)

| 모드             | 신호                                       | 산출 형태                              |
| ---------------- | ------------------------------------------ | -------------------------------------- |
| `fixed-interval` | 정기 폴링·스케줄 ("매 5분", "배포 후")     | `/loop 5m <task>` (cron 변환)          |
| `self-paced`     | 종료조건 있는 수렴 작업 ("CI 통과까지")    | `/loop <task>` (간격 생략 = 자가 페이싱·자가 종료) |
| `loop.md-default`| 브랜치/PR 상시 유지보수                    | `.claude/loop.md` 본문 (bare `/loop`)  |

`/loop` 파싱 규칙 반영: leading `^\d+[smhd]$` 또는 trailing "every…" → interval; 없으면 dynamic.
단위 `s/m/h/d`, 초→분 반올림, 안 맞는 값(`7m·90m`)은 가까운 cron step.

### Step 2 — loop skeleton 추출 (5요소 압축)

- **cadence** — interval 값 or self-paced 판정
- **task** — 매 iteration 할 일 (one focused job)
- **state/context** — 이전 iteration 결과 참조법 (git history·파일·`@file`)
- **verification** — 객관 센서 (test exit / lint / console 0 / diff / build)
- **stop** — done criteria + iteration ceiling

### Step 3 — gap 질문 (goalcraft 패턴)

빠진 필드를 우선순위로 질문 (AskUserQuestion):
1. **객관적 종료조건** (가장 damaging gap)
2. **iteration ceiling / budget**
3. **verification command**
4. **interval 값** (fixed 모드일 때)

"그냥 변환해" 하면 가정을 명시적으로 출력 아래 표기.

### Step 4 — 빌드

`references/loop-modes.md`의 해당 모드 프로필 적용.

### Step 5 — deliver

단일 fenced 코드블록. 위에 모드 1줄(`고정 5분 폴링:` / `self-paced:` / `.claude/loop.md:`),
아래 가정·대안 bullet.

---

## 4. 핵심 강제 규칙 (cross-cutting — 모든 출력에 항상)

조사에서 수렴한 검증된 규칙:

1. **객관적 종료조건 강제** — "만족할 때까지" 금지. self-paced는 "provably complete" 신호 명시
   (ralph `completion-promise`: 종료 약속은 완전히 TRUE일 때만). Loop Library 2문장 템플릿:
   *"Stop when X, progress stalls, or budget ends"* / *"Continue until no Y remains or limit ends"*.
2. **iteration ceiling 필수** — 기본 상한 명시(requesty: "Always set a ceiling. Start with 50") +
   no-progress stop. interval-less self-paced가 runaway 위험 최고.
3. **verification 센서 명시** — 매 변경마다 evidence. "반쯤 보고 done 선언" 안티패턴 차단.
4. **상태 참조** — 이전 iteration 결과를 git·파일로 참조 (중복작업 방지, research-engine ledger 정신).
5. **human gate 옵션** — 고위험(push·merge·배포·프로덕션 데이터)은 사람 게이트 슬롯 표시
   (loop-engineering 5요소와 정합).
6. **single-trial 판정 금지** — 주관·noisy 작업은 rubric+threshold 또는 N회 측정 후 판정
   (research-engine 3-way gate accept/reject/hold 정신).

`references/loop-modes.md`에 모드별로, `references/recipes.md`에 종료조건 패턴·few-shot으로 구현.

---

## 5. description 트리거 (skill-creator 최적화 대상)

- **발동**: "루프 프롬프트로 만들어줘", "/loop 용으로", "주기적으로 반복", "매 N분마다 ~",
  "~까지 반복해서", "이거 loop으로 돌려줘"
- **비발동**: 단발 작업(→goalcraft), 실행/구현 자체, loop-engineering 거버넌스, `/loop` 설명/번역

---

## 6. 검증 (evals / dogfooding)

- **evals/** (goalcraft처럼): trigger eval(발동/비발동 분류) + 변환 품질 eval.
- **dogfooding 3종**:
  1. fixed-interval ("배포 후 에러 점검") → `/loop <interval>` + 종료/ceiling 강제
  2. self-paced ("CI 통과·리뷰 해결까지") → 간격 생략 + provably-complete 종료
  3. maintenance ("이 브랜치 PR 계속 돌봐") → `loop.md` 본문
- 각 케이스에서 모드 정확 판정 + 5요소 채움 + 종료조건·ceiling 빈칸 불허 확인.

---

## 7. 배포·동기 (gprecious-marketplace HARD RULES)

- dual-tree: `claude-plugins/loopcraft/` + `.agents/plugins/plugins/loopcraft/` 양쪽 생성,
  두 `plugin.json` `version` 동시 부여.
- 카탈로그 2곳 등록: `.claude-plugin/marketplace.json` + `.agents/plugins/marketplace.json`
  (plugin 추가 = minor bump).
- README.md 표에 1행 추가.
- push 전 게이트: `python3 scripts/dual-tree-check.py` → `OK: 버전 skew 없음`.
- owner 확인: `gh auth status` + `git remote -v` → `gprecious` 계정.
- 작업 마무리 = `git push origin <branch>` 까지 (commit만으로 끝 아님).

---

## 8. 합의된 결정 사항 (브레인스토밍 결과)

1. 타깃 = **Claude Code `/loop` 전용** (executor-adaptive ❌).
2. 산출물 = **`/loop` 명령 + 선택적 `loop.md` 본문** (backend/감사 ❌ — loop-engineering 영역).
3. 배포 = **gprecious-marketplace 플러그인** (dual-tree).
4. 구조 = **goalcraft 동형** (`SKILL.md` + `references/loop-modes.md`·`recipes.md`).
5. 경계 = **goalcraft(단발) / loopcraft(반복) / loop-engineering(거버넌스)** 3자 분업.

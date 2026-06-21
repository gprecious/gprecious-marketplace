# loopcraft 플러그인 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 반복 업무 요구사항을 Claude Code `/loop` 용 프롬프트로 변환하는 `loopcraft` 스킬 플러그인을 gprecious-marketplace에 dual-tree로 추가한다 (goalcraft의 loop 형제).

**Architecture:** goalcraft(`claude-plugins/goalcraft/`)와 **동형 구조**를 복제한다 — `SKILL.md`(워크플로) + `references/`(loop-modes·recipes) + `evals/evals.json`. Claude Code 트리(`claude-plugins/loopcraft/`)와 Codex 트리(`.agents/plugins/plugins/loopcraft/`) 양쪽을 함께 만들고, 두 마켓 카탈로그에 등록한다. 산출물은 prompt/skill 마크다운이므로 "테스트"는 **dual-tree-check.py 게이트 + 스킬 발동 + dogfooding 변환 시연** 3종으로 한다.

**Tech Stack:** Markdown skills, JSON manifests(plugin.json·marketplace.json), Python(`scripts/dual-tree-check.py`), git worktree.

**작업 디렉토리:** `/Users/taejin/Documents/dev/gprecious-marketplace-wt-loopcraft` (브랜치 `feat/loopcraft`, main 기준). 모든 경로는 이 worktree 기준 repo-relative.

**참조 원본 (복사 금지, 형식만 미러링):**
- `claude-plugins/goalcraft/` (Claude 트리 구조·plugin.json·README)
- `.agents/plugins/plugins/goalcraft/` (Codex 트리 구조·`.codex-plugin/plugin.json`)
- `~/.codex/skills/goalcraft/references/claude-code.md` (프로필 형식), `evals/evals.json` (eval 형식)
- 본 plan과 같은 폴더의 `2026-06-21-loopcraft-design.md` (SoT — §3 워크플로·§4 강제규칙·§5 트리거)

---

## Task 0: 사전 확인 — goalcraft 실제 구조 파악

**목적:** 미러링 대상의 정확한 디렉토리 레이아웃·plugin.json 필드·version 관례를 확정한다.

**Step 1: goalcraft 양 트리 구조 덤프**

```bash
cd /Users/taejin/Documents/dev/gprecious-marketplace-wt-loopcraft
find claude-plugins/goalcraft .agents/plugins/plugins/goalcraft -type f | sort
cat claude-plugins/goalcraft/.claude-plugin/plugin.json
cat .agents/plugins/plugins/goalcraft/.codex-plugin/plugin.json
```

**Step 2: 확인 사항 기록**
- plugin.json 필수 필드(name/version/description/author)와 keywords 값 형태
- version 관례 (goalcraft가 1.0.0인지 0.x인지 → loopcraft 초기 version 결정)
- skills 하위 경로가 `skills/goalcraft/SKILL.md`인지, references/evals 위치
- Codex 트리가 `bin/` wrapper 등 **플랫폼 전용 블록**을 갖는지 (있으면 loopcraft도 보존 대상)

**검증:** goalcraft 파일 트리가 출력되고 plugin.json 두 개를 읽었다. 결과를 다음 Task들의 템플릿으로 사용.

**커밋 없음** (읽기 전용 확인).

---

## Task 1: Claude 트리 스캐폴딩 + plugin.json

**Files:**
- Create: `claude-plugins/loopcraft/.claude-plugin/plugin.json`

**Step 1: 디렉토리 생성**

```bash
mkdir -p claude-plugins/loopcraft/.claude-plugin
mkdir -p claude-plugins/loopcraft/skills/loopcraft/references
mkdir -p claude-plugins/loopcraft/skills/loopcraft/evals
```

**Step 2: plugin.json 작성** (Task 0에서 확인한 version 관례 적용; 아래는 0.1.0 가정)

```json
{
  "name": "loopcraft",
  "version": "0.1.0",
  "description": "반복 업무 요구사항을 Claude Code /loop 용 프롬프트로 변환. goalcraft의 loop 형제. 모드 판정(고정 interval/self-paced/loop.md) 후 객관적 종료조건·iteration ceiling·verification을 박은 복붙용 /loop 프롬프트 생성.",
  "author": {
    "name": "gprecious",
    "email": "<goalcraft와 동일 값 사용>"
  },
  "keywords": ["loop", "claude-code", "prompt", "automation", "recurring"]
}
```

> CLAUDE.md 스키마 준수: `commands`/`agents`/`skills` 키 금지(auto-discovery), `features`/`requiredEnvVars` 금지.

**Step 3: 검증**

```bash
python3 -c "import json; json.load(open('claude-plugins/loopcraft/.claude-plugin/plugin.json'))" && echo "JSON OK"
```
Expected: `JSON OK`

**Step 4: 커밋**

```bash
git add claude-plugins/loopcraft/.claude-plugin/plugin.json
git commit -m "feat(loopcraft): Claude 트리 plugin.json 스캐폴딩"
```

---

## Task 2: SKILL.md 작성 (핵심)

**Files:**
- Create: `claude-plugins/loopcraft/skills/loopcraft/SKILL.md`

**Step 1: frontmatter + 본문 작성**

design §3(워크플로 5스텝)·§4(강제규칙 6종)·§5(트리거)를 본문으로 구현. goalcraft SKILL.md 톤·길이(~8KB) 미러. 구조:

- `---` frontmatter: `name: loopcraft`, `description:` — design §5 트리거 문구(발동/비발동) 한·영 혼합, goalcraft description 스타일. **goalcraft·loop-engineering과 비발동 경계 명시**("단발은 goalcraft, 거버넌스는 loop-engineering").
- `# Loopcraft — Requirements → Claude Code /loop Prompt` 도입부: "coding agent가 done처럼 보이면 멈춘다 / 루프는 객관적 종료조건이 멈춤 신호" 프레이밍.
- `## Step 1 — 모드 판정`: 3모드 표(design §3 Step1) + `/loop` 파싱 규칙(leading `^\d+[smhd]$` / trailing "every" / 없으면 dynamic), 단위 s/m/h/d, 초→분·7m/90m 반올림.
- `## Step 2 — loop skeleton 추출`: 5요소(cadence/task/state/verification/stop).
- `## Step 3 — gap 질문`: 우선순위 ①종료조건 ②ceiling ③verification ④interval. AskUserQuestion 사용, "그냥 변환해"면 가정 명시.
- `## Step 4 — 빌드`: `references/loop-modes.md` 해당 모드 프로필 적용 안내(@ 참조).
- `## Step 5 — deliver`: 단일 fenced 블록 + 상단 모드 라벨 + 하단 가정·대안.
- `## 항상 적용 규칙`: design §4 6종 요약(객관 종료/ceiling/verification/상태참조/human gate/single-trial 금지). 상세는 `references/`로.

**Step 2: 검증 — 스킬 발동 트리거**

worktree에서 새 세션/현 세션 인식이 어려우므로, frontmatter description을 design §5와 대조 점검(발동 트리거 6개·비발동 4개 포함 여부 수동 체크).

```bash
head -5 claude-plugins/loopcraft/skills/loopcraft/SKILL.md   # frontmatter 확인
wc -c claude-plugins/loopcraft/skills/loopcraft/SKILL.md     # 대략 6~9KB
```

**Step 3: 검증 — dogfooding (가장 중요)**

SKILL.md를 스스로 읽고 3 케이스를 손으로 변환해보며 누락 검출:
1. fixed: "preview 배포 후 콘솔 에러 점검" → `/loop <interval> ...` + 종료·ceiling 들어가나?
2. self-paced: "CI 통과·리뷰 코멘트 해결까지 반복" → 간격 생략 + provably-complete 종료 나오나?
3. maintenance: "이 브랜치 PR 계속 돌봐줘" → `.claude/loop.md` 본문 안내 나오나?

세 케이스 모두 5요소·종료조건·ceiling이 강제되면 통과. 빠지면 SKILL.md 보강 후 재시도.

**Step 4: 커밋**

```bash
git add claude-plugins/loopcraft/skills/loopcraft/SKILL.md
git commit -m "feat(loopcraft): SKILL.md — 모드판정·5요소·강제규칙 워크플로"
```

---

## Task 3: references/loop-modes.md

**Files:**
- Create: `claude-plugins/loopcraft/skills/loopcraft/references/loop-modes.md`

**Step 1: 3모드 프로필 작성** (goalcraft `references/claude-code.md` 형식 미러)

각 모드별 섹션: **언제 쓰나 / 명령 형태 / 종료조건 작성법 / 가드레일 / before→after 예시 1개**.

- `## fixed-interval` — `/loop <N>[smhd] <task>`. cron 변환·jitter·7일 만료 언급. 종료=수동/만료, 단 task에 "변화 없으면 1줄로 보고" 권고. 예: `/loop 5m 배포 상태 확인, 끝났으면 결과 요약, 아직이면 한 줄로 대기 보고`.
- `## self-paced` — `/loop <task>`(간격 생략). Claude가 1분~1시간 자가 페이싱, **provably complete면 자가 종료**. 종료조건을 객관 신호로("CI green + 미해결 리뷰 0"), ceiling 명시. Monitor 도구 활용 가능 언급. before→after.
- `## loop.md-default` — `.claude/loop.md`(>`~/.claude/loop.md`) 본문. bare `/loop`이 매 iteration 재로드(25KB cap). 유지보수 프롬프트 예시(release 브랜치 헬스). built-in maintenance prompt와의 관계.

각 섹션에 design §4 강제규칙을 해당 모드 맥락으로 박는다(특히 ceiling은 self-paced에 강조).

**Step 2: 검증**

```bash
grep -c "^## " claude-plugins/loopcraft/skills/loopcraft/references/loop-modes.md   # 3개 모드 섹션
```
Expected: `3` 이상

**Step 3: 커밋**

```bash
git add claude-plugins/loopcraft/skills/loopcraft/references/loop-modes.md
git commit -m "feat(loopcraft): references/loop-modes.md — 3모드 작성 프로필"
```

---

## Task 4: references/recipes.md

**Files:**
- Create: `claude-plugins/loopcraft/skills/loopcraft/references/recipes.md`

**Step 1: 종료조건 패턴 + few-shot 작성**

- `## 종료조건 문장 패턴` — Loop Library 2템플릿: *"Stop when X, progress stalls, or budget ends"* / *"Continue until no Y remains or limit ends"*. ralph completion-promise 원칙(거짓 종료 금지) 1줄.
- `## few-shot 레시피` — 5~6개. 각 항목: 입력(거친 요구) → 출력(`/loop` 명령 or loop.md) + 모드 라벨. Loop Library 44개에서 개발 맥락으로 번역(예: docs-drift-sweep, lint-type-sweep, e2e-healer, preview-error-sweep, PR-babysit, dependency-bump-check). **각 레시피에 객관 종료조건·ceiling·verification이 들어간 모범 출력**을 보인다.
- `## 안티패턴` — "만족할 때까지"(주관 종료), ceiling 없음, "반쯤 보고 done", verification 없는 변경. 각각 교정 방향.

**Step 2: 검증**

```bash
grep -c "/loop" claude-plugins/loopcraft/skills/loopcraft/references/recipes.md   # 레시피 예시 다수
```
Expected: `5` 이상

**Step 3: 커밋**

```bash
git add claude-plugins/loopcraft/skills/loopcraft/skills 2>/dev/null; git add claude-plugins/loopcraft/skills/loopcraft/references/recipes.md
git commit -m "feat(loopcraft): references/recipes.md — 종료조건 패턴·few-shot 시드"
```

---

## Task 5: evals/evals.json

**Files:**
- Create: `claude-plugins/loopcraft/skills/loopcraft/evals/evals.json`

**Step 1: goalcraft evals.json 형식으로 작성**

`{ "skill_name": "loopcraft", "evals": [...] }`. 각 eval: `id`, `name`, `prompt`, `expected_output`, `files: []`, `assertions: []`. 최소 4개:
1. `vague-recurring-default` — "preview 배포되면 에러 점검 계속 돌려줘" → 모드=fixed/self-paced 판정, 종료조건·ceiling 질문 또는 가정, 복붙 `/loop` 블록.
2. `self-paced-convergence` — "CI 통과하고 리뷰 코멘트 다 처리될 때까지 반복" → 간격 생략 self-paced, provably-complete 객관 종료, ceiling.
3. `maintenance-loopmd` — "이 브랜치 PR 계속 돌봐줘" → `.claude/loop.md` 본문 산출.
4. `single-shot-reject` — "로그인 버그 한 번 고쳐줘" → 단발로 판정, **goalcraft로 라우팅 안내**(loopcraft 변환 거부).

**Step 2: 검증**

```bash
python3 -c "import json; d=json.load(open('claude-plugins/loopcraft/skills/loopcraft/evals/evals.json')); print('evals:', len(d['evals']))"
```
Expected: `evals: 4` 이상

**Step 3: 커밋**

```bash
git add claude-plugins/loopcraft/skills/loopcraft/evals/evals.json
git commit -m "test(loopcraft): evals.json — 트리거·변환·라우팅 eval 4종"
```

---

## Task 6: README.md (플러그인)

**Files:**
- Create: `claude-plugins/loopcraft/README.md`

**Step 1: 작성** (goalcraft 플러그인 README 톤 미러)

설치/사용 1줄 예시, 3모드 요약 표, 3자 경계(goalcraft/loopcraft/loop-engineering), 강제규칙 6종 bullet.

**Step 2: 커밋**

```bash
git add claude-plugins/loopcraft/README.md
git commit -m "docs(loopcraft): 플러그인 README"
```

---

## Task 7: Codex 트리 미러 (.agents/plugins/plugins/loopcraft)

**Files:**
- Create: `.agents/plugins/plugins/loopcraft/.codex-plugin/plugin.json`
- Create: `.agents/plugins/plugins/loopcraft/skills/loopcraft/SKILL.md` (+ references/·evals/)
- Create: `.agents/plugins/plugins/loopcraft/README.md`

**Step 1: 구조 복제** — Task 0에서 본 goalcraft Codex 트리 레이아웃대로 디렉토리 생성.

**Step 2: 파일 미러** — SKILL/references/recipes/evals/README를 Claude 트리에서 가져오되, **CLAUDE.md HARD RULE 준수**:
- SKILL 내용은 의미 기준 reconcile. **맹목 복사 금지** — goalcraft Codex 트리에 `bin/` wrapper 경로 해석 등 플랫폼 전용 블록이 있으면 loopcraft에도 동일 패턴 적용, 없으면 동일 내용.
- `.codex-plugin/plugin.json`은 Codex 스키마(Task 0에서 확인), **version은 Claude 트리와 동일**(0.1.0).

```bash
mkdir -p .agents/plugins/plugins/loopcraft/.codex-plugin
mkdir -p .agents/plugins/plugins/loopcraft/skills/loopcraft/references
mkdir -p .agents/plugins/plugins/loopcraft/skills/loopcraft/evals
cp claude-plugins/loopcraft/skills/loopcraft/SKILL.md .agents/plugins/plugins/loopcraft/skills/loopcraft/SKILL.md
cp claude-plugins/loopcraft/skills/loopcraft/references/*.md .agents/plugins/plugins/loopcraft/skills/loopcraft/references/
cp claude-plugins/loopcraft/skills/loopcraft/evals/evals.json .agents/plugins/plugins/loopcraft/skills/loopcraft/evals/
cp claude-plugins/loopcraft/README.md .agents/plugins/plugins/loopcraft/README.md
# .codex-plugin/plugin.json은 goalcraft Codex 매니페스트 형식으로 손작성
```

**Step 3: 검증 — 두 트리 version 일치**

```bash
python3 -c "import json; a=json.load(open('claude-plugins/loopcraft/.claude-plugin/plugin.json'))['version']; b=json.load(open('.agents/plugins/plugins/loopcraft/.codex-plugin/plugin.json'))['version']; print('match' if a==b else 'SKEW', a, b)"
```
Expected: `match 0.1.0 0.1.0`

**Step 4: 커밋**

```bash
git add .agents/plugins/plugins/loopcraft
git commit -m "feat(loopcraft): Codex 트리 미러 (dual-tree)"
```

---

## Task 8: 카탈로그 2곳 등록 + version bump + repo README 동기

**Files:**
- Modify: `.claude-plugin/marketplace.json` (loopcraft entry + 카탈로그 version bump)
- Modify: `.agents/plugins/marketplace.json` (동일)
- Modify: `README.md` (repo 루트 — plugin 표 1행)

**Step 1: Claude 카탈로그 등록** — `plugins[]`에 goalcraft entry 다음 형식으로 추가:

```json
{
  "name": "loopcraft",
  "description": "반복 업무를 Claude Code /loop 용 프롬프트로 변환. goalcraft의 loop 형제 — 모드 판정(고정 interval/self-paced/loop.md) 후 객관적 종료조건·iteration ceiling·verification을 박은 복붙용 /loop 프롬프트 생성. 단발은 goalcraft, 루프 거버넌스는 loop-engineering.",
  "source": "./claude-plugins/loopcraft",
  "category": "productivity"
}
```
+ 카탈로그 최상위 `version`을 minor bump (plugin 추가 = minor).

**Step 2: Codex 카탈로그 등록** — `.agents/plugins/marketplace.json`에 동일 entry(source는 Codex 트리 관례 확인 후) + version bump.

**Step 3: repo README.md** — plugin 표에 loopcraft 행 추가(goalcraft 행 형식 미러).

**Step 4: 검증 — JSON 유효성**

```bash
for f in .claude-plugin/marketplace.json .agents/plugins/marketplace.json; do python3 -c "import json; json.load(open('$f')); print('$f OK')"; done
```
Expected: 둘 다 `OK`

**Step 5: 커밋**

```bash
git add .claude-plugin/marketplace.json .agents/plugins/marketplace.json README.md
git commit -m "feat(loopcraft): 양 카탈로그 등록 + version bump + README 동기"
```

---

## Task 9: dual-tree-check 게이트 + 최종 dogfooding

**Step 1: dual-tree-check 게이트** (push 전 HARD GATE)

```bash
python3 scripts/dual-tree-check.py
```
Expected: `OK: 버전 skew 없음` 출력, loopcraft가 SKEW로 안 뜸. (기존 e2e-harness/youtube 비대칭은 무관.)

**Step 2: 최종 dogfooding** — Task 2 Step 3의 3 케이스 + Task 5의 single-shot-reject 케이스를 완성된 스킬로 재실행. 4개 모두 기대 동작(모드 판정/5요소/종료조건/ceiling/라우팅) 충족 확인.

**Step 3: SKILL 내용 차이 점검** — dual-tree-check가 보고하는 "SKILL 내용 차이"에 loopcraft가 의도치 않게 끼지 않는지(양 트리 SKILL이 의미상 동일한지) 확인.

**커밋 없음** (검증 단계; 문제 발견 시 해당 Task로 복귀).

---

## Task 10: push 전 main reconcile + push

**Step 1: origin/main 동기 확인** (⚠️ 로컬 main이 origin/main과 분기 상태였음)

```bash
git fetch origin main
git log --oneline --graph origin/main feat/loopcraft -10
```
- feat/loopcraft가 origin/main에서 깔끔히 갈라졌는지 확인. 분기/충돌이면 사용자에게 보고하고 rebase 여부 결정.

**Step 2: owner 확인** (글로벌 규칙)

```bash
gh auth status   # gprecious 계정인지
git -C . remote -v   # origin이 gprecious/gprecious-marketplace
```

**Step 3: push** (사용자 승인 후 — 공유 원격 변경)

```bash
git push -u origin feat/loopcraft
```

**Step 4: PR 생성 여부** — 사용자에게 PR vs 직접 main 머지 의사 확인 (finishing-a-development-branch 스킬 활용).

> **HARD RULE 체크리스트 (완료 보고 전):** ① dual-tree-check OK ② 양 plugin.json version 일치 ③ 카탈로그 2곳 + README 동기 ④ `git status -sb`에 `ahead` 없음(push 완료) ⑤ owner=gprecious.

---

## 실행 메모

- 산출물이 마크다운/JSON이라 전통 RED→GREEN이 아니다. 각 Task의 "테스트"는 **JSON 유효성 + dual-tree-check + dogfooding 변환 시연**이다. dogfooding에서 종료조건·ceiling 누락이 잡히면 그것이 RED 신호.
- design `2026-06-21-loopcraft-design.md`가 SoT. 본문 작성 중 판단이 흔들리면 design §3·§4로 복귀.
- worktree 절대경로 유지(subagent cwd hijack 주의). 모든 파일은 `feat/loopcraft` 트리에만.

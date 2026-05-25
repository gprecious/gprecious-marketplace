# analyze-service codebase input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `analyze-service` / `/market` accept a local codebase directory (not just a service URL) as input, recording `source_type` and making `voc` conditionally required (web-only).

**Architecture:** Extend the existing skill-first growth-marketer plugin. Add a `source_type` field + a `x-required-when` conditional-required construct to the `service-profile` data contract; add a 4th conditional pass to the generic jq validator; branch the `analyze-service` skill to read a local directory (README/manifest/docs) when the input is a path. Mirror all changes to the Codex copy.

**Tech Stack:** Markdown SKILL/command, JSON Schema (x-required hints), `jq` validator, `bats` tests. No build, no deps.

**Spec:** `docs/superpowers/specs/2026-05-25-analyze-service-codebase-input-design.md`
**Builds on:** Plan 1 (already merged to main). All plugin files live under `claude-plugins/growth-marketer/`, with skill deps inside `skills/analyze-service/`. Codex mirror at `.agents/plugins/plugins/growth-marketer/`.

---

## File Structure (changed/added)

```
claude-plugins/growth-marketer/
├── commands/market.md                                   # MODIFY (usage)
├── README.md                                            # MODIFY (usage)
└── skills/analyze-service/
    ├── SKILL.md                                         # MODIFY (input + local_dir branch)
    ├── schemas/service-profile.schema.json             # MODIFY (source_type + x-required-when)
    ├── scripts/validate-artifact.sh                    # MODIFY (4th conditional pass)
    └── tests/
        ├── validate-artifact.bats                      # MODIFY (+2 tests)
        └── fixtures/
            ├── service-profile.valid.json              # MODIFY (+source_type: web)
            ├── service-profile.localdir.valid.json     # CREATE
            └── service-profile.web-novoc.invalid.json  # CREATE
.agents/plugins/plugins/growth-marketer/skills/analyze-service/  # MIRROR of the above skill tree
.agents/plugins/plugins/growth-marketer/.codex-plugin/plugin.json # MODIFY (longDescription, optional)
```

---

## Task 1: Contract + validator conditional-required (TDD)

**Files:**
- Create: `claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/service-profile.localdir.valid.json`
- Create: `claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/service-profile.web-novoc.invalid.json`
- Modify: `claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats`
- Modify: `claude-plugins/growth-marketer/skills/analyze-service/schemas/service-profile.schema.json`
- Modify: `claude-plugins/growth-marketer/skills/analyze-service/scripts/validate-artifact.sh`
- Modify: `claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/service-profile.valid.json`

Work from repo root (the worktree root). `cd` there for all commands.

- [ ] **Step 1: Create the two new fixtures (RED inputs)**

Create `…/tests/fixtures/service-profile.localdir.valid.json` (source_type=local_dir, NO voc — must pass after impl):
```json
{
  "source_urls": ["./README.md", "./package.json"],
  "captured_at": "2026-05-25T09:00:00Z",
  "source_type": "local_dir",
  "icp": {
    "segment": "인디 개발자·소규모 팀",
    "pains": ["스토어 릴리즈 수작업"],
    "goals": ["빠른 배포"]
  },
  "positioning": {
    "value_prop": "크로스스택 앱 릴리즈 자동화",
    "category": "devtools/release",
    "differentiators": ["Expo·Capacitor 어댑터"]
  },
  "channel_signals": {
    "product_type": "web_saas",
    "market": "global",
    "price_model": "free",
    "target": "b2b",
    "discovery_intent": "high"
  },
  "evidence": [
    { "claim": "package.json 에 expo 의존성 존재", "source_url": "./package.json" }
  ]
}
```

Create `…/tests/fixtures/service-profile.web-novoc.invalid.json` (source_type=web, NO voc — must FAIL on conditional voc after impl):
```json
{
  "source_urls": ["https://example.com"],
  "captured_at": "2026-05-25T09:00:00Z",
  "source_type": "web",
  "icp": { "segment": "x", "pains": ["p"], "goals": ["g"] },
  "positioning": { "value_prop": "v", "category": "c" },
  "channel_signals": {
    "product_type": "web_saas", "market": "kr", "price_model": "paid", "target": "b2c", "discovery_intent": "high"
  },
  "evidence": [ { "claim": "c", "source_url": "https://example.com" } ]
}
```

- [ ] **Step 2: Add the two failing tests**

Append to `…/tests/validate-artifact.bats`:
```bash
@test "service-profile local_dir without voc passes" {
  run "$VALIDATE" service-profile "$FIX/service-profile.localdir.valid.json"
  [ "$status" -eq 0 ]
}

@test "service-profile web without voc fails (conditional)" {
  run "$VALIDATE" service-profile "$FIX/service-profile.web-novoc.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"voc"* ]]
}
```

- [ ] **Step 3: Run to verify RED**

Run: `bats claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats`
Expected: the `local_dir without voc passes` test FAILS (current schema still lists `voc` in `x-required`, so the validator flags missing voc → status 1, not 0). (The `web without voc` test may already pass against the old message — that's fine; the local_dir test is the RED.)

- [ ] **Step 4: Reshape the schema**

In `…/schemas/service-profile.schema.json`:

(a) Replace the `x-required` line:
```json
  "x-required": ["source_urls", "captured_at", "icp", "voc", "positioning", "evidence", "channel_signals"],
```
with (remove `voc`, add `source_type`, and add the conditional construct right after):
```json
  "x-required": ["source_urls", "captured_at", "source_type", "icp", "positioning", "evidence", "channel_signals"],
  "x-required-when": [
    { "field": "voc", "when": { "source_type": "web" } }
  ],
```

(b) Update the top-level `description` to:
```json
  "description": "validated by scripts/validate-artifact.sh via x-required / x-required-item / x-required-when hints (not standard JSON Schema 'required'). source_urls and *.source_url hold a URL (web) or a local file path (local_dir).",
```

(c) Add a `source_type` property (place it right after `captured_at`):
```json
    "source_type": { "type": "string", "enum": ["web", "local_dir"] },
```

(d) Update the `voc` property description to:
```json
      "description": "voice-of-customer quotes from reviews/social (web only; required when source_type=web)",
```

- [ ] **Step 5: Add the 4th (conditional) validator pass**

In `…/scripts/validate-artifact.sh`, insert this block AFTER the array-item pass (after its closing `done < <(...)` line, i.e. right before the final `if [ "$errors" -gt 0 ]` block):
```bash
# conditional required keys (schema .x-required-when):
# field required when every key/value in `when` matches the artifact.
while IFS= read -r rule; do
  [ -z "$rule" ] && continue
  field=$(jq -r '.field' <<<"$rule")
  when_all=$(jq --argjson rule "$rule" '. as $a | [ ($rule.when // {}) | to_entries[] | ($a[.key] == .value) ] | all' "$ARTIFACT")
  if [ "$when_all" = "true" ]; then
    if ! jq -e --arg f "$field" 'has($f) and (.[$f] != null)' "$ARTIFACT" >/dev/null; then
      cond=$(jq -rc '.when' <<<"$rule")
      echo "missing conditionally-required field: $field (when $cond)"
      errors=$((errors+1))
    fi
  fi
done < <(jq -c '(."x-required-when" // [])[]' "$SCHEMA")
```
This stays generic: schemas without `x-required-when` (e.g. channel-scores) iterate an empty list → no-op.

- [ ] **Step 6: Update the existing valid fixture to declare source_type**

In `…/tests/fixtures/service-profile.valid.json`, add `"source_type": "web",` right after the `captured_at` line (it already has `voc`, so it remains valid as a web fixture).

- [ ] **Step 7: Run to verify GREEN**

Run: `bats claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats`
Expected: all 9 tests PASS. Specifically `local_dir without voc passes` → status 0; `web without voc fails (conditional)` → status 1 with output containing `voc` (message `missing conditionally-required field: voc (when {"source_type":"web"})`). Confirm `channel-scores` tests still pass (4th pass is a no-op for that schema).

- [ ] **Step 8: Commit**

```bash
git add claude-plugins/growth-marketer/skills/analyze-service/schemas/service-profile.schema.json \
        claude-plugins/growth-marketer/skills/analyze-service/scripts/validate-artifact.sh \
        claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats \
        claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/service-profile.valid.json \
        claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/service-profile.localdir.valid.json \
        claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/service-profile.web-novoc.invalid.json
git commit -m "feat(growth-marketer): source_type + conditional-required voc (x-required-when) in service-profile contract"
```

---

## Task 2: analyze-service skill — source_type detection + local_dir branch

**Files:**
- Modify: `claude-plugins/growth-marketer/skills/analyze-service/SKILL.md`

- [ ] **Step 1: Overwrite SKILL.md with the extended content**

Write `…/skills/analyze-service/SKILL.md` with exactly:

````markdown
---
name: analyze-service
description: |
  내 서비스를 분석해 ICP + VOC(고객의 목소리) + 포지셔닝을 추출하고 적합 마케팅 채널을
  점수·근거로 추천한다. 입력은 (1) 서비스 URL(앱스토어/랜딩페이지, 연결된 브라우저로 읽음)
  또는 (2) 로컬 코드베이스 디렉토리 경로(README·manifest·docs 를 읽음) 둘 다 가능 — 자동 감지.
  "내 서비스 분석", "마케팅 채널 추천해줘", "이 앱 어디에 광고하지", "ICP 뽑아줘",
  "이 코드베이스/레포 분석해서 마케팅", "로컬 프로젝트 분석" 같은 요청에 발동.
  결과는 .growth-marketer/<slug>/ 아래 구조화 파일로 저장된다.
---

# analyze-service

서비스 URL 또는 로컬 코드베이스를 읽어 구조화된 서비스 프로파일과 채널 추천을 만든다.
모든 산출물은 데이터 계약(schemas/)을 따르고 validate-artifact.sh 로 검증한다.

## 입력
- 필수: 내 서비스 **URL**(앱스토어 리스팅/랜딩페이지) **또는 로컬 코드베이스 디렉토리 경로** 중 하나.
- 선택: 경쟁사 URL 목록.

## 절차
1. **slug + source_type 결정** — 서비스명에서 kebab-case slug. 입력 자동 감지:
   `http(s)://...` → `source_type="web"`; 존재하는 디렉토리 경로 → `source_type="local_dir"`.
   산출 루트: `<repo-root>/.growth-marketer/<slug>/` (.growth-marketer/ 는 repo 루트 기준;
   사용자 프로젝트 .gitignore 에 .growth-marketer/ 가 없으면 추가한다). `runs/<ISO8601>/`
   스냅샷 디렉토리도 만든다 (UTC·초단위, 예: 2026-05-25T09:00:00Z).
2. **소스 읽기 (source_type 분기)**
   - **web**: `mcp__claude-in-chrome__*` 로 메인 리스팅/랜딩(가치제안·카테고리·기능·가격)과
     리뷰/소셜(실제 사용자 문장 VOC + source URL)을 읽는다. 봇 차단 회피를 위해 사용자의
     실제 로그인 세션을 그대로 사용(headless 금지).
   - **local_dir** (브라우저 불필요): 디렉토리에서 README(.md), `package.json`/`app.json`/
     `pubspec.yaml`/`Info.plist`/`manifest.json`, `docs/`, 랜딩·마케팅 카피, 소스 트리 구조를
     읽는다. product_type 은 manifest 로 추론(expo/capacitor/flutter/ios/android→mobile_app,
     next/react/vite/web→web_saas). market/price_model/target/discovery_intent 는 best-effort
     추론. VOC 는 코드에 없으므로 비운다(선택).
3. **경쟁사 (선택, live)** — 경쟁사 URL 이 있으면 동일하게 읽고, 더 깊은 시장 스캔이 필요하면
   research-engine `/research` 를 호출한다. 경쟁사에서 얻은 사실은 service-profile.json 의
   evidence[](source_url 포함) 와 positioning.differentiators 에 반영한다(별도 파일 없음).
4. **service-profile.json 작성** — `schemas/service-profile.schema.json` 스키마대로:
   `source_type`, icp(segment/pains/goals), positioning(value_prop/category/differentiators),
   evidence[](claim+source_url — URL 또는 로컬 파일 경로), channel_signals(product_type/market/
   price_model/target/discovery_intent). `voc[]`(quote+source_url)는 **source_type=web 일 때만
   필수**, local_dir 이면 비운다. 모든 주장에 출처(URL 또는 파일 경로)를 부착한다.
5. **채널 스코어링** — `references/channel-fit-rubric.md` 규칙으로 각 채널 0~5 점 + rationale,
   recommendation(primary/secondary/why) 산출 → `channel-scores.json`
   (`schemas/channel-scores.schema.json` 준수).
6. **service-brief.md 작성** — 사람이 읽는 요약(프로파일 핵심 + 추천 채널 + 근거).
7. **검증 (필수 게이트)** — 두 산출물을 검증한다. 실패하면 누락 필드를 채워 다시 저장:
   검증기·스키마·rubric 은 이 skill 폴더(skills/analyze-service/) 안에 있다 — Claude/Codex 양쪽 동일 상대경로.
   ```bash
   bash skills/analyze-service/scripts/validate-artifact.sh service-profile <slug-dir>/service-profile.json
   bash skills/analyze-service/scripts/validate-artifact.sh channel-scores  <slug-dir>/channel-scores.json
   ```
8. **보고** — 추천 채널과 근거를 자연어로 요약하고, 저장된 파일 경로를 알린다.

## 데이터 계약 / drift 규칙
- `service-profile.json` 이 단일 진실 공급원(SoT). 재분석 시 통째 덮어쓰지 말고
  `runs/<ts>/` 에 스냅샷을 남기고 SoT 대비 diff 를 brief 에 기록한다.
- 자유문 산출 금지 — 항상 스키마 섹션을 채운다.

## 출력
- `.growth-marketer/<slug>/service-profile.json` (SoT)
- `.growth-marketer/<slug>/service-brief.md`
- `.growth-marketer/<slug>/channel-scores.json`
- `.growth-marketer/<slug>/runs/<ts>/` 스냅샷

## 안전
- web 은 chrome 읽기 전용, local_dir 은 파일시스템 읽기 전용(이 skill 은 입력/발행 없음).
- 모델 호출은 OAuth/구독 CLI 만, 과금 API 키 금지(마켓 정책).
- 다음 단계(generate-copy/channel-playbook/cro-audit)는 이 산출물을 입력으로 받는다.
````

- [ ] **Step 2: Verify**

Run:
```bash
f=claude-plugins/growth-marketer/skills/analyze-service/SKILL.md
head -1 "$f" | grep -q '^---$' && echo "frontmatter OK"
grep -q 'source_type' "$f" && echo "source_type OK"
grep -q 'local_dir' "$f" && echo "local_dir OK"
grep -q 'validate-artifact.sh' "$f" && echo "validator ref OK"
```
Expected: four OK lines.

- [ ] **Step 3: Commit**

```bash
git add claude-plugins/growth-marketer/skills/analyze-service/SKILL.md
git commit -m "feat(growth-marketer): analyze-service accepts local codebase dir (source_type branch)"
```

---

## Task 3: /market command + README usage

**Files:**
- Modify: `claude-plugins/growth-marketer/commands/market.md`
- Modify: `claude-plugins/growth-marketer/README.md`

- [ ] **Step 1: Overwrite the command**

Write `…/commands/market.md` with exactly:
```markdown
---
description: 서비스 URL 또는 로컬 코드베이스를 분석하고 적합 마케팅 채널을 추천한다 (analyze-service 진입점)
---

# /market

사용법: `/market <서비스 URL | 로컬 코드베이스 경로> [경쟁사 URL ...]`

이 커맨드는 analyze-service skill 을 호출해 다음을 순서대로 수행한다:
1. 입력을 자동 감지 — URL 이면 Claude-in-Chrome 으로, 로컬 디렉토리 경로면 코드베이스
   파일(README·manifest·docs)을 읽어 service-profile.json(`source_type` 포함) 작성.
2. channel-fit-rubric 으로 채널 점수·추천(channel-scores.json) 산출.
3. validate-artifact.sh 로 두 산출물 검증.
4. 추천 채널·근거 요약 + 저장 경로 보고.

이후 단계(카피 생성·플레이북·CRO 감사·draft 캠페인)는 별도 skill 로 이어간다.
인자가 없으면 사용자에게 서비스 URL 또는 코드베이스 경로를 묻는다.
```

- [ ] **Step 2: Update the plugin README usage**

In `…/README.md`, in the "v1 (Plan 1) 제공 기능" / 동작 원리 area, update the `/market` and `analyze-service` lines so they state the input can be a **서비스 URL 또는 로컬 코드베이스 디렉토리** (auto-detected). Concretely, change the `/market <URL>` mention to `/market <서비스 URL | 로컬 코드베이스 경로>`, and add to the analyze-service line that it reads a connected browser (web) **또는 로컬 코드베이스 파일(README·manifest·docs)**. Keep the rest of the README intact. Do not change the bats path.

- [ ] **Step 3: Verify**

Run:
```bash
grep -q '로컬 코드베이스' claude-plugins/growth-marketer/commands/market.md && echo "command OK"
grep -q '코드베이스' claude-plugins/growth-marketer/README.md && echo "readme OK"
```
Expected: two OK lines.

- [ ] **Step 4: Commit**

```bash
git add claude-plugins/growth-marketer/commands/market.md claude-plugins/growth-marketer/README.md
git commit -m "feat(growth-marketer): /market + README document local codebase input"
```

---

## Task 4: Sync Codex mirror

**Files:**
- Replace: `.agents/plugins/plugins/growth-marketer/skills/` (mirror of the updated skill tree)
- Modify (optional): `.agents/plugins/plugins/growth-marketer/.codex-plugin/plugin.json` (longDescription)

- [ ] **Step 1: Re-mirror the skill tree**

```bash
cd /REPO_ROOT  # the worktree root
rm -rf .agents/plugins/plugins/growth-marketer/skills
cp -R claude-plugins/growth-marketer/skills .agents/plugins/plugins/growth-marketer/skills
```
(Replace `/REPO_ROOT` with the actual worktree path.) Only `skills/` is mirrored to Codex — `commands/` and top-level README are not part of the Codex plugin (consistent with existing siblings).

- [ ] **Step 2: Update the Codex longDescription (optional but preferred)**

In `.agents/plugins/plugins/growth-marketer/.codex-plugin/plugin.json`, update the `interface.longDescription` so it mentions input can be a service URL **or a local codebase directory**. Keep JSON valid. Do not change other fields.

- [ ] **Step 3: Verify the mirror is self-contained and identical**

```bash
cd /REPO_ROOT
diff -r claude-plugins/growth-marketer/skills .agents/plugins/plugins/growth-marketer/skills && echo "MIRROR IDENTICAL"
bats .agents/plugins/plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats
jq -e . .agents/plugins/plugins/growth-marketer/.codex-plugin/plugin.json >/dev/null && echo "codex plugin.json OK"
```
Expected: `MIRROR IDENTICAL`; 9 bats tests pass; `codex plugin.json OK`.

- [ ] **Step 4: Commit**

```bash
git add .agents/plugins/plugins/growth-marketer
git commit -m "chore(growth-marketer): sync Codex mirror for codebase input"
```

---

## Task 5: Full verification + final review

**Files:** none (verification only).

- [ ] **Step 1: Deterministic verification**

```bash
cd /REPO_ROOT
bats claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats
bats .agents/plugins/plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats
jq -e . claude-plugins/growth-marketer/skills/analyze-service/schemas/service-profile.schema.json >/dev/null && echo "schema OK"
jq -e . .claude-plugin/marketplace.json >/dev/null && jq -e . .agents/plugins/marketplace.json >/dev/null && echo "marketplaces OK"
# probe: local_dir without voc passes; web without voc fails on conditional
cd claude-plugins/growth-marketer/skills/analyze-service
./scripts/validate-artifact.sh service-profile tests/fixtures/service-profile.localdir.valid.json; echo "localdir rc=$?"
./scripts/validate-artifact.sh service-profile tests/fixtures/service-profile.web-novoc.invalid.json; echo "web-novoc rc=$? (expect 1, msg mentions voc)"
```
Expected: 9 tests pass from both locations; schema + marketplaces valid; localdir rc=0; web-novoc rc=1 with a `conditionally-required field: voc` message.

- [ ] **Step 2: Manual smoke (HARD GATE — note if not run)**

Run `/market <a local codebase directory you control>` and confirm `service-profile.json` is written with `source_type: "local_dir"`, validates OK, and `voc` may be empty. Also confirm the web path still works with a real URL. If the connected Claude-in-Chrome / a real codebase isn't available in the environment, explicitly report "smoke not run" rather than claiming success.

- [ ] **Step 3: (Controller) dispatch final code reviewer** for the whole branch diff vs the branch point, then proceed to finishing-a-development-branch.

---

## Self-Review (completed by plan author)

- **Spec coverage:** §2 input model → Task 2 step1 detection + Task 3 usage. §3 contract (source_type, x-required-when, voc removed from unconditional, source_url meaning) → Task 1 step4. §4 validator 4th pass → Task 1 step5. §5 skill local_dir branch → Task 2. §6 command/README → Task 3. §7 Codex mirror + tests → Task 1 (tests) + Task 4 (mirror). §9 verification → Task 5. All covered.
- **Placeholder scan:** `/REPO_ROOT` in Tasks 4–5 is a concrete instruction to substitute the worktree root (the controller provides it), not a vague TODO. All code/JSON/bats steps contain full content. No TBD.
- **Type/name consistency:** `source_type` enum `web`/`local_dir`, `x-required-when` rule shape `{field, when}`, fixture filenames (`service-profile.localdir.valid.json`, `service-profile.web-novoc.invalid.json`), and the validator message `missing conditionally-required field: <field> (when <cond>)` are consistent across schema, validator, tests, and skill. The validator stays schema-generic (channel-scores unaffected).

# growth-marketer Foundation Implementation Plan (Plan 1 of 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a registered, working `growth-marketer` Claude Code plugin skeleton with the data-contract layer and the `analyze-service` skill + `/market` entry, so a user can analyze a service URL and get a validated `service-profile.json` + `channel-scores.json` + brief.

**Architecture:** skill-first / MCP-driven plugin (no build). Skills are thin orchestration; business logic lives in baked references + JSON-Schema data contracts. `analyze-service` drives the connected Claude-in-Chrome MCP to read pages/reviews, emits versioned structured artifacts under `.growth-marketer/<slug>/`, validated by a `jq`-based contract validator. A hand-authored baseline `channel-fit-rubric.md` powers channel recommendation (research-enriched later in Plan 2).

**Tech Stack:** Markdown SKILL/command files, JSON Schema (data contracts), `jq` (validator), `bats` (tests). No compiled code, no package deps.

**Spec:** `docs/superpowers/specs/2026-05-25-growth-marketer-design.md`

**Plan roadmap (context — only Plan 1 is detailed here):**
- **Plan 1 (this):** Foundation + data contract + `analyze-service` + `/market`.
- **Plan 2:** research (herdr fan-out ~18 topics) → bake `references/` + `data/`.
- **Plan 3:** content skills — `generate-copy`, `channel-playbook`, `cro-audit`.
- **Plan 4:** automation + QA — `draft-campaign` (chrome + verification gate), `review-assets`.

---

## File Structure (Plan 1 scope)

```
claude-plugins/growth-marketer/
├── .claude-plugin/plugin.json     # plugin manifest (name/version/description/author/keywords)
├── README.md                      # usage
├── .gitignore                     # ignore .growth-marketer/ artifact output
├── commands/market.md             # thin entry: analyze → channel recommendation
├── skills/analyze-service/SKILL.md # service analysis (ICP+VOC+positioning) via chrome MCP
├── references/channel-fit-rubric.md # hand-authored baseline scoring rubric
├── schemas/
│   ├── service-profile.schema.json
│   └── channel-scores.schema.json
├── scripts/validate-artifact.sh   # jq-based contract validator
└── tests/
    ├── validate-artifact.bats
    └── fixtures/
        ├── service-profile.valid.json
        ├── service-profile.invalid.json
        ├── channel-scores.valid.json
        └── channel-scores.invalid.json
```

`marketplace.json` is modified (add plugin entry + version bump). The runtime artifact
root `.growth-marketer/<slug>/` is user output and is git-ignored.

---

## Task 1: Plugin scaffold + marketplace registration

**Files:**
- Create: `claude-plugins/growth-marketer/.claude-plugin/plugin.json`
- Create: `claude-plugins/growth-marketer/.gitignore`
- Modify: `.claude-plugin/marketplace.json` (add entry, bump version `1.x.0`)

- [ ] **Step 1: Create the plugin manifest**

Create `claude-plugins/growth-marketer/.claude-plugin/plugin.json`:

```json
{
  "name": "growth-marketer",
  "version": "0.1.0",
  "description": "내 제품(모바일 앱·웹/SaaS) 마케팅 자동화 — 서비스 분석(ICP·VOC), 채널 추천, 인지심리학 기반 카피·플레이북, 광고 플랫폼 draft 자동입력(발행은 사람). Claude-in-Chrome MCP 구동.",
  "author": {
    "name": "gprecious",
    "email": "gprecious@users.noreply.github.com"
  },
  "keywords": ["marketing", "growth", "ads", "cro", "copywriting", "aso", "chrome"]
}
```

- [ ] **Step 2: Create the artifact .gitignore**

Create `claude-plugins/growth-marketer/.gitignore`:

```gitignore
# runtime artifact output (per-service, user work product — not committed)
.growth-marketer/
```

- [ ] **Step 3: Register in marketplace.json + bump version**

Modify `.claude-plugin/marketplace.json`: add this object to the `plugins` array (after the `herdr` entry):

```json
    {
      "name": "growth-marketer",
      "description": "내 제품(모바일 앱·웹/SaaS) 마케팅 자동화 — 서비스 분석(ICP·VOC), 채널 추천, 인지심리학 기반 카피·플레이북, 광고 플랫폼 draft 자동입력(발행은 사람).",
      "source": "./claude-plugins/growth-marketer",
      "category": "productivity"
    }
```

There is no top-level `version` key in the current marketplace.json (it uses `metadata.description`). Do NOT invent a `version` key — leave the file's existing top-level keys as-is. Only append the plugin entry.

- [ ] **Step 4: Verify both JSON files parse**

Run:
```bash
jq -e . claude-plugins/growth-marketer/.claude-plugin/plugin.json >/dev/null && echo "plugin.json OK"
jq -e '.plugins[] | select(.name=="growth-marketer")' .claude-plugin/marketplace.json >/dev/null && echo "registered OK"
```
Expected: both print `OK`.

- [ ] **Step 5: Commit**

```bash
git add claude-plugins/growth-marketer/.claude-plugin/plugin.json \
        claude-plugins/growth-marketer/.gitignore \
        .claude-plugin/marketplace.json
git commit -m "feat(growth-marketer): scaffold plugin + register in marketplace"
```

---

## Task 2: Data contract — service-profile schema + jq validator (TDD)

**Files:**
- Create: `claude-plugins/growth-marketer/schemas/service-profile.schema.json`
- Create: `claude-plugins/growth-marketer/scripts/validate-artifact.sh`
- Create: `claude-plugins/growth-marketer/tests/validate-artifact.bats`
- Create: `claude-plugins/growth-marketer/tests/fixtures/service-profile.valid.json`
- Create: `claude-plugins/growth-marketer/tests/fixtures/service-profile.invalid.json`

- [ ] **Step 1: Define the service-profile data contract**

Create `claude-plugins/growth-marketer/schemas/service-profile.schema.json`. This is the
single source of truth produced by `analyze-service`. We validate it with jq (not a full
JSON-Schema engine), so the validator reads the `x-required` and `x-required-item` hints
below.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "service-profile",
  "type": "object",
  "x-required": ["source_urls", "captured_at", "icp", "voc", "positioning", "evidence"],
  "properties": {
    "source_urls": { "type": "array", "items": { "type": "string" } },
    "captured_at": { "type": "string", "description": "ISO-8601 timestamp" },
    "icp": {
      "type": "object",
      "x-required": ["segment", "pains", "goals"],
      "properties": {
        "segment": { "type": "string" },
        "pains": { "type": "array", "items": { "type": "string" } },
        "goals": { "type": "array", "items": { "type": "string" } }
      }
    },
    "voc": {
      "type": "array",
      "description": "voice-of-customer quotes mined from reviews/social",
      "items": {
        "type": "object",
        "x-required-item": ["quote", "source_url"],
        "properties": {
          "quote": { "type": "string" },
          "source_url": { "type": "string" },
          "sentiment": { "type": "string" }
        }
      }
    },
    "positioning": {
      "type": "object",
      "x-required": ["value_prop", "category"],
      "properties": {
        "value_prop": { "type": "string" },
        "category": { "type": "string" },
        "differentiators": { "type": "array", "items": { "type": "string" } }
      }
    },
    "evidence": {
      "type": "array",
      "description": "every claim ties to a source",
      "items": {
        "type": "object",
        "x-required-item": ["claim", "source_url"],
        "properties": {
          "claim": { "type": "string" },
          "source_url": { "type": "string" }
        }
      }
    }
  }
}
```

- [ ] **Step 2: Create test fixtures**

Create `claude-plugins/growth-marketer/tests/fixtures/service-profile.valid.json`:

```json
{
  "source_urls": ["https://apps.apple.com/app/id000"],
  "captured_at": "2026-05-25T09:00:00Z",
  "icp": {
    "segment": "20-30대 자기계발 관심 직장인",
    "pains": ["습관 유지 실패"],
    "goals": ["꾸준한 루틴 형성"]
  },
  "voc": [
    { "quote": "알림이 딱 맞는 타이밍에 와서 좋아요", "source_url": "https://apps.apple.com/app/id000#review1", "sentiment": "positive" }
  ],
  "positioning": {
    "value_prop": "행동심리 기반 습관 코치",
    "category": "productivity/habit",
    "differentiators": ["맥락 알림"]
  },
  "evidence": [
    { "claim": "리뷰 4.6점", "source_url": "https://apps.apple.com/app/id000" }
  ]
}
```

Create `claude-plugins/growth-marketer/tests/fixtures/service-profile.invalid.json` (missing `positioning` and a `voc` item missing `source_url`):

```json
{
  "source_urls": ["https://apps.apple.com/app/id000"],
  "captured_at": "2026-05-25T09:00:00Z",
  "icp": { "segment": "x", "pains": [], "goals": [] },
  "voc": [ { "quote": "출처 없는 인용" } ],
  "evidence": []
}
```

- [ ] **Step 3: Write the failing test**

Create `claude-plugins/growth-marketer/tests/validate-artifact.bats`:

```bash
#!/usr/bin/env bats

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VALIDATE="$ROOT/scripts/validate-artifact.sh"
FIX="$ROOT/tests/fixtures"

@test "service-profile valid fixture passes" {
  run "$VALIDATE" service-profile "$FIX/service-profile.valid.json"
  [ "$status" -eq 0 ]
}

@test "service-profile invalid fixture fails with missing-field message" {
  run "$VALIDATE" service-profile "$FIX/service-profile.invalid.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"positioning"* ]]
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `bats claude-plugins/growth-marketer/tests/validate-artifact.bats`
Expected: FAIL — `validate-artifact.sh` does not exist yet (command not found / non-zero with no field message).

- [ ] **Step 5: Implement the validator**

Create `claude-plugins/growth-marketer/scripts/validate-artifact.sh` and `chmod +x` it:

```bash
#!/usr/bin/env bash
# Validate a produced artifact against its schema's x-required / x-required-item hints.
# Usage: validate-artifact.sh <schema-name> <artifact.json>
set -euo pipefail

SCHEMA_NAME="${1:?usage: validate-artifact.sh <schema-name> <artifact.json>}"
ARTIFACT="${2:?usage: validate-artifact.sh <schema-name> <artifact.json>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="$ROOT/schemas/${SCHEMA_NAME}.schema.json"

[ -f "$SCHEMA" ]   || { echo "schema not found: $SCHEMA"; exit 2; }
jq -e . "$ARTIFACT" >/dev/null 2>&1 || { echo "artifact is not valid JSON: $ARTIFACT"; exit 2; }

errors=0

# top-level required keys (schema .x-required)
while IFS= read -r key; do
  [ -z "$key" ] && continue
  if ! jq -e --arg k "$key" 'has($k) and (.[$k] != null)' "$ARTIFACT" >/dev/null; then
    echo "missing required field: $key"
    errors=$((errors+1))
  fi
done < <(jq -r '(."x-required" // [])[]' "$SCHEMA")

# nested object required keys (properties.<p>.x-required) — only checked if parent present
while IFS= read -r parent; do
  [ -z "$parent" ] && continue
  jq -e --arg p "$parent" 'has($p)' "$ARTIFACT" >/dev/null || continue
  while IFS= read -r sub; do
    [ -z "$sub" ] && continue
    if ! jq -e --arg p "$parent" --arg s "$sub" '.[$p] | (has($s) and (.[$s] != null))' "$ARTIFACT" >/dev/null; then
      echo "missing required field: ${parent}.${sub}"
      errors=$((errors+1))
    fi
  done < <(jq -r --arg p "$parent" '.properties[$p]."x-required" // [] | .[]' "$SCHEMA")
done < <(jq -r '.properties | to_entries[] | select(.value | has("x-required")) | .key' "$SCHEMA")

# array item required keys (properties.<p>.items.x-required-item)
while IFS= read -r arrkey; do
  [ -z "$arrkey" ] && continue
  jq -e --arg p "$arrkey" 'has($p)' "$ARTIFACT" >/dev/null || continue
  while IFS= read -r itemreq; do
    [ -z "$itemreq" ] && continue
    bad=$(jq --arg p "$arrkey" --arg r "$itemreq" '[.[$p][] | select((has($r) | not) or (.[$r] == null))] | length' "$ARTIFACT")
    if [ "$bad" != "0" ]; then
      echo "array '$arrkey' has $bad item(s) missing required field: $itemreq"
      errors=$((errors+1))
    fi
  done < <(jq -r --arg p "$arrkey" '.properties[$p].items."x-required-item" // [] | .[]' "$SCHEMA")
done < <(jq -r '.properties | to_entries[] | select(.value.items | type=="object" and has("x-required-item")) | .key' "$SCHEMA")

if [ "$errors" -gt 0 ]; then
  echo "FAIL: $errors contract violation(s) in $ARTIFACT"
  exit 1
fi
echo "OK: $ARTIFACT conforms to $SCHEMA_NAME"
```

Then: `chmod +x claude-plugins/growth-marketer/scripts/validate-artifact.sh`

- [ ] **Step 6: Run the test to verify it passes**

Run: `bats claude-plugins/growth-marketer/tests/validate-artifact.bats`
Expected: PASS (2 tests). The invalid fixture must emit a line containing `positioning`.

- [ ] **Step 7: Commit**

```bash
git add claude-plugins/growth-marketer/schemas/service-profile.schema.json \
        claude-plugins/growth-marketer/scripts/validate-artifact.sh \
        claude-plugins/growth-marketer/tests/validate-artifact.bats \
        claude-plugins/growth-marketer/tests/fixtures/service-profile.valid.json \
        claude-plugins/growth-marketer/tests/fixtures/service-profile.invalid.json
git commit -m "feat(growth-marketer): service-profile data contract + jq validator (TDD)"
```

---

## Task 3: channel-scores contract + baseline channel-fit-rubric

**Files:**
- Create: `claude-plugins/growth-marketer/schemas/channel-scores.schema.json`
- Create: `claude-plugins/growth-marketer/references/channel-fit-rubric.md`
- Create: `claude-plugins/growth-marketer/tests/fixtures/channel-scores.valid.json`
- Create: `claude-plugins/growth-marketer/tests/fixtures/channel-scores.invalid.json`
- Modify: `claude-plugins/growth-marketer/tests/validate-artifact.bats` (append 2 tests)

- [ ] **Step 1: Define the channel-scores contract**

Create `claude-plugins/growth-marketer/schemas/channel-scores.schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "channel-scores",
  "type": "object",
  "x-required": ["service_slug", "scored_at", "scores", "recommendation"],
  "properties": {
    "service_slug": { "type": "string" },
    "scored_at": { "type": "string" },
    "scores": {
      "type": "array",
      "items": {
        "type": "object",
        "x-required-item": ["channel", "score", "rationale"],
        "properties": {
          "channel": { "type": "string", "enum": ["meta", "google-ads", "naver", "aso", "seo", "retargeting"] },
          "score": { "type": "number" },
          "rationale": { "type": "string" }
        }
      }
    },
    "recommendation": {
      "type": "object",
      "x-required": ["primary", "why"],
      "properties": {
        "primary": { "type": "string" },
        "secondary": { "type": "array", "items": { "type": "string" } },
        "why": { "type": "string" }
      }
    }
  }
}
```

- [ ] **Step 2: Author the baseline channel-fit-rubric**

Create `claude-plugins/growth-marketer/references/channel-fit-rubric.md`:

```markdown
# channel-fit-rubric (baseline v0)

> 하드코딩 baseline — Plan 2 research 가 출처와 함께 보강한다. analyze-service 가
> service-profile 의 속성을 아래 신호에 매핑해 0~5 점을 매기고 근거를 단다.

## 입력 신호 (service-profile 에서)
- product_type: mobile_app | web_saas
- market: kr | global | both
- price_model: free | freemium | paid | subscription
- target: b2c | b2b
- discovery_intent: high(사람들이 검색함) | low(수요 창출 필요)

## 채널별 점수 가이드 (0~5)
| 채널 | 강한 신호(+) | 약한 신호(-) |
|---|---|---|
| aso | mobile_app | web_saas only |
| google-ads | discovery_intent=high, global/both | 순수 수요창출만 필요 |
| naver | market=kr 또는 both | global only |
| meta | b2c, 시각적 소구, 수요창출 | b2b 니치 |
| seo | web_saas, 콘텐츠 여력, 장기 | 즉시 전환 필요 |
| retargeting | 트래픽 이미 있음 | 콜드 스타트(트래픽 0) |

## 산출 규칙
- 각 채널 score + 한 줄 rationale(어떤 신호 때문인지).
- recommendation.primary = 최고점 채널, secondary = 2~3순위, why = 종합 근거.
- 동점이면 product_type 주채널(mobile_app→aso, web_saas→seo) 우선.
```

- [ ] **Step 3: Create channel-scores fixtures**

Create `claude-plugins/growth-marketer/tests/fixtures/channel-scores.valid.json`:

```json
{
  "service_slug": "habit-coach",
  "scored_at": "2026-05-25T09:10:00Z",
  "scores": [
    { "channel": "aso", "score": 5, "rationale": "mobile_app 주채널" },
    { "channel": "meta", "score": 4, "rationale": "b2c 시각 소구" }
  ],
  "recommendation": { "primary": "aso", "secondary": ["meta"], "why": "모바일 앱 + b2c" }
}
```

Create `claude-plugins/growth-marketer/tests/fixtures/channel-scores.invalid.json` (a score item missing `rationale`, and missing `recommendation`):

```json
{
  "service_slug": "habit-coach",
  "scored_at": "2026-05-25T09:10:00Z",
  "scores": [ { "channel": "aso", "score": 5 } ]
}
```

- [ ] **Step 4: Append failing tests**

Append to `claude-plugins/growth-marketer/tests/validate-artifact.bats`:

```bash
@test "channel-scores valid fixture passes" {
  run "$VALIDATE" channel-scores "$FIX/channel-scores.valid.json"
  [ "$status" -eq 0 ]
}

@test "channel-scores invalid fixture fails" {
  run "$VALIDATE" channel-scores "$FIX/channel-scores.invalid.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"recommendation"* ]]
}
```

- [ ] **Step 5: Run tests**

Run: `bats claude-plugins/growth-marketer/tests/validate-artifact.bats`
Expected: PASS — all 4 tests. (The validator from Task 2 is schema-driven, so no code change is needed; the new schema + fixtures drive the new cases.)

- [ ] **Step 6: Commit**

```bash
git add claude-plugins/growth-marketer/schemas/channel-scores.schema.json \
        claude-plugins/growth-marketer/references/channel-fit-rubric.md \
        claude-plugins/growth-marketer/tests/fixtures/channel-scores.valid.json \
        claude-plugins/growth-marketer/tests/fixtures/channel-scores.invalid.json \
        claude-plugins/growth-marketer/tests/validate-artifact.bats
git commit -m "feat(growth-marketer): channel-scores contract + baseline channel-fit-rubric"
```

---

## Task 4: `analyze-service` skill

**Files:**
- Create: `claude-plugins/growth-marketer/skills/analyze-service/SKILL.md`

- [ ] **Step 1: Author the SKILL**

Create `claude-plugins/growth-marketer/skills/analyze-service/SKILL.md`:

````markdown
---
name: analyze-service
description: |
  내 서비스(모바일 앱 스토어 리스팅 / 웹·SaaS 랜딩페이지)를 연결된 브라우저로 읽어
  ICP + VOC(고객의 목소리) + 포지셔닝을 추출하고, 적합 마케팅 채널을 점수와 근거로
  추천한다. "내 서비스 분석", "마케팅 채널 추천해줘", "이 앱 어디에 광고하지",
  "ICP 뽑아줘", "리뷰 분석해서 포지셔닝" 같은 요청에 발동.
  결과는 .growth-marketer/<slug>/ 아래 구조화 파일로 저장된다.
---

# analyze-service

연결된 Claude-in-Chrome MCP 로 서비스 페이지·리뷰를 읽어 구조화된 서비스 프로파일과
채널 추천을 만든다. 모든 산출물은 데이터 계약(schemas/)을 따르고 validate-artifact.sh
로 검증한다.

## 입력
- 필수: 내 서비스 URL (앱스토어 리스팅 또는 랜딩페이지).
- 선택: 경쟁사 URL 목록.

## 절차
1. **slug 결정** — 서비스명에서 kebab-case slug. 산출 루트:
   `<project>/.growth-marketer/<slug>/`. `runs/<ISO8601>/` 스냅샷 디렉토리도 만든다.
2. **페이지 읽기 (chrome MCP)** — `mcp__claude-in-chrome__*` 로:
   - 메인 리스팅/랜딩: 가치제안·카테고리·기능·가격.
   - 리뷰/소셜: 실제 사용자 문장(VOC) 인용을 source URL 과 함께 수집.
   봇 차단 회피를 위해 사용자의 실제 로그인 세션을 그대로 사용(headless 금지).
3. **경쟁사 (선택, live)** — 경쟁사 URL 이 있으면 동일하게 읽고, 더 깊은 시장
   스캔이 필요하면 research-engine `/research` 를 호출한다.
4. **service-profile.json 작성** — `schemas/service-profile.schema.json` 스키마대로:
   icp(segment/pains/goals), voc[](quote+source_url), positioning(value_prop/
   category/differentiators), evidence[](claim+source_url). 모든 주장에 출처 부착.
   추가로 채널 스코어링에 쓸 신호(product_type/market/price_model/target/
   discovery_intent)를 positioning 또는 별도 필드로 기록.
5. **채널 스코어링** — `references/channel-fit-rubric.md` 규칙으로 각 채널 0~5 점 +
   rationale, recommendation(primary/secondary/why) 산출 →
   `channel-scores.json` (`schemas/channel-scores.schema.json` 준수).
6. **service-brief.md 작성** — 사람이 읽는 요약(프로파일 핵심 + 추천 채널 + 근거).
7. **검증 (필수 게이트)** — 두 산출물을 검증한다. 실패하면 누락 필드를 채워 다시 저장:
   ```bash
   SKILL_DIR="$(dirname "$0")"  # 또는 플러그인 루트 기준 절대경로
   bash <plugin>/scripts/validate-artifact.sh service-profile <slug-dir>/service-profile.json
   bash <plugin>/scripts/validate-artifact.sh channel-scores  <slug-dir>/channel-scores.json
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
- chrome 은 읽기만(이 skill 은 입력/발행 없음).
- 모델 호출은 OAuth/구독 CLI 만, 과금 API 키 금지(마켓 정책).
- 다음 단계(generate-copy/channel-playbook/cro-audit)는 이 산출물을 입력으로 받는다.
````

- [ ] **Step 2: Verify frontmatter + contract references**

Run:
```bash
f=claude-plugins/growth-marketer/skills/analyze-service/SKILL.md
head -1 "$f" | grep -q '^---$' && echo "frontmatter start OK"
grep -q 'validate-artifact.sh' "$f" && echo "validator referenced OK"
grep -q 'channel-fit-rubric' "$f" && echo "rubric referenced OK"
```
Expected: three `OK` lines.

- [ ] **Step 3: Commit**

```bash
git add claude-plugins/growth-marketer/skills/analyze-service/SKILL.md
git commit -m "feat(growth-marketer): analyze-service skill (ICP/VOC + channel scoring)"
```

---

## Task 5: `/market` command + README

**Files:**
- Create: `claude-plugins/growth-marketer/commands/market.md`
- Create: `claude-plugins/growth-marketer/README.md`
- Modify: `README.md` (repo root — sync plugin table)

- [ ] **Step 1: Author the command**

Create `claude-plugins/growth-marketer/commands/market.md`:

```markdown
---
description: 서비스 URL 을 분석하고 적합 마케팅 채널을 추천한다 (analyze-service 진입점)
---

# /market

사용법: `/market <서비스 URL> [경쟁사 URL ...]`

이 커맨드는 analyze-service skill 을 호출해 다음을 순서대로 수행한다:
1. 입력 URL(들)을 Claude-in-Chrome 으로 읽어 service-profile.json 작성.
2. channel-fit-rubric 으로 채널 점수·추천(channel-scores.json) 산출.
3. validate-artifact.sh 로 두 산출물 검증.
4. 추천 채널·근거 요약 + 저장 경로 보고.

이후 단계(카피 생성·플레이북·CRO 감사·draft 캠페인)는 별도 skill 로 이어간다.
인자가 없으면 사용자에게 서비스 URL 을 묻는다.
```

- [ ] **Step 2: Author the plugin README**

Create `claude-plugins/growth-marketer/README.md`:

```markdown
# growth-marketer

내 제품(모바일 앱·웹/SaaS)의 마케팅을 자동화하는 Claude Code 플러그인.
서비스 분석(ICP·VOC) → 채널 추천 → (이후 plan) 카피·플레이북·CRO·draft 캠페인.

## v1 (Plan 1) 제공 기능
- `/market <URL>` — 서비스 분석 + 채널 추천.
- `analyze-service` skill — Claude-in-Chrome 으로 페이지·리뷰를 읽어 구조화 프로파일
  + 채널 스코어 산출. 결과는 `.growth-marketer/<slug>/` 에 저장(데이터 계약 준수).

## 동작 원리
- skill-first / MCP-driven (무빌드). 브라우저 자동화는 연결된 Claude-in-Chrome MCP.
- 산출물은 `schemas/` 의 데이터 계약을 따르고 `scripts/validate-artifact.sh` 로 검증.
- 채널 추천 근거는 `references/channel-fit-rubric.md`.

## 안전
- 모델 호출은 OAuth/구독 CLI 만(과금 API 키 금지).
- 이 단계는 읽기 전용(브라우저 입력/발행 없음).

## 테스트
```bash
bats claude-plugins/growth-marketer/tests/validate-artifact.bats
```

## 로드맵
- Plan 2: research → references/ baking (인지심리학·채널 방법론).
- Plan 3: generate-copy / channel-playbook / cro-audit.
- Plan 4: draft-campaign(검증 게이트) / review-assets.
```

- [ ] **Step 3: Sync repo-root README plugin table**

Open repo-root `README.md`, find the plugin list/table, and add a `growth-marketer` row
consistent with existing rows (name, 한 줄 설명, 설치/사용). Match the existing table's
exact column format. If the README has an install-commands section, add the
`growth-marketer` install line in the same style as the other plugins.

- [ ] **Step 4: Verify**

Run:
```bash
test -f claude-plugins/growth-marketer/commands/market.md && echo "command OK"
grep -q 'growth-marketer' README.md && echo "root README synced OK"
```
Expected: two `OK` lines.

- [ ] **Step 5: Commit**

```bash
git add claude-plugins/growth-marketer/commands/market.md \
        claude-plugins/growth-marketer/README.md \
        README.md
git commit -m "feat(growth-marketer): /market command + README sync"
```

---

## Task 6: Plugin smoke verification (manual — chrome cannot be unit-tested)

**Files:** none (verification only).

- [ ] **Step 1: Run the contract test suite**

Run: `bats claude-plugins/growth-marketer/tests/validate-artifact.bats`
Expected: all 4 tests PASS.

- [ ] **Step 2: Manual end-to-end smoke (HARD GATE before declaring done)**

In a Claude Code session with the connected Claude-in-Chrome MCP available, run
`/market <a real app-store or landing URL you control>`. Confirm:
- `.growth-marketer/<slug>/service-profile.json` exists and `validate-artifact.sh
  service-profile <path>` prints `OK`.
- `.growth-marketer/<slug>/channel-scores.json` exists and validates `OK`.
- `service-brief.md` summarizes ICP/VOC/positioning + a channel recommendation with
  rationale.
- Every VOC quote and evidence claim carries a `source_url`.

If the MCP is unavailable in the environment, explicitly report "UI/chrome smoke not
run" rather than claiming success (per project HARD GATE).

- [ ] **Step 3: Final commit (if any fixups were needed)**

```bash
git add -A claude-plugins/growth-marketer
git commit -m "test(growth-marketer): plan 1 smoke verification fixups"
```

---

## Self-Review (completed by plan author)

- **Spec coverage (Plan 1 portion):** §2 approach A ✓ (no-build, MCP-driven). §3 folder
  structure ✓ (subset: plugin.json, README, .gitignore, commands, analyze-service skill,
  channel-fit-rubric, schemas, scripts, tests). §4 analyze-service ✓ (Task 4). §5 data
  contract layer ✓ (Tasks 2–3: schemas + validator + SoT/runs/diff rules in SKILL). §9
  safety (auth, read-only) ✓. §11 testing ✓ (Task 2/3/6). Deferred to later plans:
  generate-copy/channel-playbook/cro-audit/draft-campaign/review-assets (Plans 3–4),
  references baking + data/*.json + frameworks + quality-standards (Plan 2),
  draft-campaign verification gate §6 (Plan 4). These are out of Plan 1 scope by design.
- **Placeholder scan:** Task 5 Step 3 (root README row) is an in-codebase edit against an
  existing file whose exact table format isn't reproduced here — it gives the concrete
  action + verification grep, not a vague "update docs". All code/JSON/bats steps contain
  full content. No TBD/TODO.
- **Type/name consistency:** schema names `service-profile` / `channel-scores` match
  validator usage, fixture filenames, bats calls, and SKILL output paths. `validate-artifact.sh`
  signature `<schema-name> <artifact.json>` consistent across Tasks 2/3/4/6. Artifact root
  `.growth-marketer/<slug>/` consistent across .gitignore, SKILL, command, README.

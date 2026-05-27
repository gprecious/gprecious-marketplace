# DataForSEO Enrichment for analyze-service — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional DataForSEO (HTTP) enrichment to the growth-marketer `analyze-service` skill so search-volume + Google/Naver SERP data sharpen `discovery_intent`, `market`, competitor `evidence`, and channel scores — degrading gracefully when credentials are absent.

**Architecture:** A self-contained `scripts/dataforseo.sh` reads credentials from 1Password (`op read`) and calls DataForSEO Live endpoints via `curl`, emitting a contract-validated `seo-enrichment.json`. The existing generic `validate-artifact.sh` validates it against a new schema (no validator code change). A `DFS_FIXTURE_DIR` test seam lets bats exercise the parsing logic with canned responses — no network, no `op`. The `analyze-service` SKILL gains an optional enrichment step that folds results into the existing `service-profile.json` contract.

**Tech Stack:** bash, curl, jq, bats, 1Password CLI (`op`), DataForSEO REST API v3.

---

## File Structure

- Create `claude-plugins/growth-marketer/skills/analyze-service/schemas/seo-enrichment.schema.json` — contract for enrichment output.
- Create `claude-plugins/growth-marketer/skills/analyze-service/scripts/dataforseo.sh` — auth + HTTP + parse → `seo-enrichment.json`.
- Create `claude-plugins/growth-marketer/skills/analyze-service/references/serp-to-channel.md` — SERP feature/volume → channel weighting rules.
- Create fixtures under `claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/`:
  - `seo-enrichment.valid.json`, `seo-enrichment.invalid.json` (schema tests)
  - `dfs/search_volume.json`, `dfs/serp_google.json`, `dfs/serp_naver.json` (script-seam tests)
- Modify `claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats` — add schema + script tests.
- Modify `claude-plugins/growth-marketer/skills/analyze-service/SKILL.md` — insert optional enrichment step, extend validation gate + outputs.
- Modify `claude-plugins/growth-marketer/README.md` — note SEO enrichment.
- Mirror the whole `skills/analyze-service/` tree to `.agents/plugins/plugins/growth-marketer/skills/analyze-service/`.

`validate-artifact.sh` is **unchanged** — it is already generic over `x-required` / nested `x-required` / `x-required-item`.

---

### Task 1: seo-enrichment data contract (schema + fixtures + bats)

**Files:**
- Create: `claude-plugins/growth-marketer/skills/analyze-service/schemas/seo-enrichment.schema.json`
- Create: `claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/seo-enrichment.valid.json`
- Create: `claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/seo-enrichment.invalid.json`
- Modify: `claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats`

- [ ] **Step 1: Write the failing tests**

Append to `tests/validate-artifact.bats`:

```bash
@test "seo-enrichment valid fixture passes" {
  run "$VALIDATE" seo-enrichment "$FIX/seo-enrichment.valid.json"
  [ "$status" -eq 0 ]
}

@test "seo-enrichment invalid fixture fails with missing-field messages" {
  run "$VALIDATE" seo-enrichment "$FIX/seo-enrichment.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"search_volume"* ]]
  [[ "$output" == *"rank"* ]]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats -f seo-enrichment`
Expected: FAIL — `seo-enrichment.schema.json` does not exist yet, so the validator exits 2 ("schema not found"), not 0 / 1.

- [ ] **Step 3: Create the schema**

`schemas/seo-enrichment.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "seo-enrichment",
  "description": "DataForSEO-derived market evidence for analyze-service. All source_url values are DataForSEO endpoint URLs.",
  "type": "object",
  "x-required": ["query", "markets", "search_volume", "serp_competitors", "captured_at"],
  "properties": {
    "query": { "type": "string", "description": "The category keyword queried." },
    "markets": {
      "type": "array",
      "items": { "type": "string", "enum": ["kr", "global"] },
      "description": "Geo markets queried."
    },
    "search_volume": {
      "type": "object",
      "x-required": ["value", "source_url"],
      "properties": {
        "value": { "type": "number", "description": "Monthly search volume (Google Ads)." },
        "source_url": { "type": "string" }
      }
    },
    "serp_competitors": {
      "type": "array",
      "items": {
        "type": "object",
        "x-required-item": ["domain", "rank", "source_url"],
        "properties": {
          "domain": { "type": "string" },
          "rank": { "type": "number" },
          "url": { "type": "string" },
          "market": { "type": "string", "description": "SERP engine: google | naver." },
          "source_url": { "type": "string" }
        }
      }
    },
    "serp_features": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Distinct SERP item types observed (organic, video, local_pack, ...)."
    },
    "captured_at": { "type": "string", "description": "UTC ISO8601." }
  }
}
```

- [ ] **Step 4: Create the valid fixture**

`tests/fixtures/seo-enrichment.valid.json`:

```json
{
  "query": "헬스 트래킹 앱",
  "markets": ["kr", "global"],
  "search_volume": {
    "value": 8100,
    "source_url": "https://api.dataforseo.com/v3/keywords_data/google_ads/search_volume/live"
  },
  "serp_competitors": [
    { "domain": "competitor-a.com", "rank": 1, "url": "https://competitor-a.com/", "market": "google", "source_url": "https://api.dataforseo.com/v3/serp/google/organic/live/advanced" },
    { "domain": "blog.naver.com", "rank": 1, "url": "https://blog.naver.com/x", "market": "naver", "source_url": "https://api.dataforseo.com/v3/serp/naver/organic/live/advanced" }
  ],
  "serp_features": ["organic", "video", "people_also_ask"],
  "captured_at": "2026-05-27T09:00:00Z"
}
```

- [ ] **Step 5: Create the invalid fixture**

`tests/fixtures/seo-enrichment.invalid.json` — omits top-level `search_volume`, and the one competitor omits `rank`:

```json
{
  "query": "x",
  "markets": ["kr"],
  "serp_competitors": [
    { "domain": "a.com", "url": "https://a.com", "market": "naver", "source_url": "https://api.dataforseo.com/v3/serp/naver/organic/live/advanced" }
  ],
  "captured_at": "2026-05-27T09:00:00Z"
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bats claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats -f seo-enrichment`
Expected: PASS (2/2). The invalid case exits 1 and its output contains both `search_volume` and `rank`.

- [ ] **Step 7: Run the full suite (regression)**

Run: `bats claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats`
Expected: all prior tests still PASS plus the 2 new ones.

- [ ] **Step 8: Commit**

```bash
git add claude-plugins/growth-marketer/skills/analyze-service/schemas/seo-enrichment.schema.json \
        claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/seo-enrichment.valid.json \
        claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/seo-enrichment.invalid.json \
        claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats
git commit -m "feat(growth-marketer): seo-enrichment data contract + fixtures (TDD)"
```

---

### Task 2: dataforseo.sh (auth + HTTP + parse, with fixture seam)

**Files:**
- Create: `claude-plugins/growth-marketer/skills/analyze-service/scripts/dataforseo.sh`
- Create: `claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/dfs/search_volume.json`
- Create: `claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/dfs/serp_google.json`
- Create: `claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/dfs/serp_naver.json`
- Modify: `claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats`

- [ ] **Step 1: Create the canned DataForSEO response fixtures**

`tests/fixtures/dfs/search_volume.json`:

```json
{
  "status_code": 20000,
  "tasks": [
    {
      "status_code": 20000,
      "result": [
        { "keyword": "헬스 트래킹 앱", "search_volume": 8100, "cpc": 0.42, "competition": "LOW" }
      ]
    }
  ]
}
```

`tests/fixtures/dfs/serp_google.json`:

```json
{
  "status_code": 20000,
  "tasks": [
    {
      "status_code": 20000,
      "result": [
        {
          "keyword": "헬스 트래킹 앱",
          "items": [
            { "type": "organic", "rank_absolute": 1, "domain": "competitor-a.com", "url": "https://competitor-a.com/" },
            { "type": "organic", "rank_absolute": 2, "domain": "competitor-b.io", "url": "https://competitor-b.io/app" },
            { "type": "people_also_ask", "rank_absolute": 3 },
            { "type": "video", "rank_absolute": 4 }
          ]
        }
      ]
    }
  ]
}
```

`tests/fixtures/dfs/serp_naver.json`:

```json
{
  "status_code": 20000,
  "tasks": [
    {
      "status_code": 20000,
      "result": [
        {
          "keyword": "헬스 트래킹 앱",
          "items": [
            { "type": "organic", "rank_absolute": 1, "domain": "blog.naver.com", "url": "https://blog.naver.com/x" },
            { "type": "organic", "rank_absolute": 2, "domain": "cafe.naver.com", "url": "https://cafe.naver.com/y" }
          ]
        }
      ]
    }
  ]
}
```

- [ ] **Step 2: Write the failing tests**

Append to `tests/validate-artifact.bats`:

```bash
DFS="$ROOT/scripts/dataforseo.sh"
DFSFIX="$ROOT/tests/fixtures/dfs"

@test "dataforseo.sh both: produces contract-valid enrichment from fixtures" {
  out="$(mktemp)"
  DFS_FIXTURE_DIR="$DFSFIX" run "$DFS" "헬스 트래킹 앱" both "$out"
  [ "$status" -eq 0 ]
  run "$VALIDATE" seo-enrichment "$out"
  [ "$status" -eq 0 ]
  rm -f "$out"
}

@test "dataforseo.sh both: extracts volume + google and naver competitors + features" {
  out="$(mktemp)"
  DFS_FIXTURE_DIR="$DFSFIX" "$DFS" "헬스 트래킹 앱" both "$out"
  [ "$(jq -r '.query' "$out")" = "헬스 트래킹 앱" ]
  [ "$(jq -r '.search_volume.value' "$out")" = "8100" ]
  [ "$(jq -r '[.serp_competitors[] | select(.market=="google")] | length' "$out")" -ge 1 ]
  [ "$(jq -r '[.serp_competitors[] | select(.market=="naver")] | length' "$out")" -ge 1 ]
  [ "$(jq -r '.serp_features | index("organic")' "$out")" != "null" ]
  rm -f "$out"
}

@test "dataforseo.sh global: skips naver (no naver competitors)" {
  out="$(mktemp)"
  DFS_FIXTURE_DIR="$DFSFIX" "$DFS" "헬스 트래킹 앱" global "$out"
  [ "$(jq -r '[.serp_competitors[] | select(.market=="naver")] | length' "$out")" = "0" ]
  [ "$(jq -r '.markets' "$out")" != "null" ]
  rm -f "$out"
}

@test "dataforseo.sh: missing args exits 2" {
  run "$DFS" "헬스 트래킹 앱"
  [ "$status" -eq 2 ]
}

@test "dataforseo.sh: invalid market exits 2" {
  out="$(mktemp)"
  DFS_FIXTURE_DIR="$DFSFIX" run "$DFS" "kw" mars "$out"
  rm -f "$out"
  [ "$status" -eq 2 ]
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bats claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats -f dataforseo`
Expected: FAIL — `scripts/dataforseo.sh` does not exist (command not found / non-zero).

- [ ] **Step 4: Implement the script**

`scripts/dataforseo.sh`:

```bash
#!/usr/bin/env bash
# DataForSEO enrichment for analyze-service.
# Usage: dataforseo.sh <category-keyword> <kr|global|both> <out.json>
# Auth: 1Password (op read op://Employee/DataForSEO/{username,password}). HTTP Basic.
# Test seam: if DFS_FIXTURE_DIR is set, reads canned responses instead of calling op/curl.
# Exit codes: 0 ok | 2 usage | 3 credentials/op unavailable (caller: skip) | 4 network/API error (caller: skip)
set -euo pipefail
set +x  # never trace — credentials must not leak

KW="${1:-}"; MARKET="${2:-}"; OUT="${3:-}"
if [ -z "$KW" ] || [ -z "$MARKET" ] || [ -z "$OUT" ]; then
  echo "usage: dataforseo.sh <keyword> <kr|global|both> <out.json>" >&2
  exit 2
fi
case "$MARKET" in kr|global|both) ;; *) echo "market must be kr|global|both" >&2; exit 2 ;; esac

API="https://api.dataforseo.com"
SV_PATH="/v3/keywords_data/google_ads/search_volume/live"
G_PATH="/v3/serp/google/organic/live/advanced"
N_PATH="/v3/serp/naver/organic/live/advanced"
SV_URL="$API$SV_PATH"; G_URL="$API$G_PATH"; N_URL="$API$N_PATH"

# DataForSEO location codes: 2410=South Korea, 2840=United States.
case "$MARKET" in
  kr)     GLOC=2410; GLANG=ko ;;
  global) GLOC=2840; GLANG=en ;;
  both)   GLOC=2410; GLANG=ko ;;
esac

# Credentials only needed for live calls.
DFS_USER=""; DFS_PASS=""
if [ -z "${DFS_FIXTURE_DIR:-}" ]; then
  command -v op >/dev/null 2>&1 || { echo "op CLI not found — skip enrichment" >&2; exit 3; }
  DFS_USER="$(op read 'op://Employee/DataForSEO/username' 2>/dev/null)" || { echo "cannot read DataForSEO username from 1Password — skip" >&2; exit 3; }
  DFS_PASS="$(op read 'op://Employee/DataForSEO/password' 2>/dev/null)" || { echo "cannot read DataForSEO password from 1Password — skip" >&2; exit 3; }
  { [ -n "$DFS_USER" ] && [ -n "$DFS_PASS" ]; } || { echo "empty DataForSEO credentials — skip" >&2; exit 3; }
fi

# dfs_call <slug> <path> <json-body> -> prints response JSON (fixture in test mode, curl otherwise)
dfs_call() {
  local slug="$1" path="$2" body="$3"
  if [ -n "${DFS_FIXTURE_DIR:-}" ]; then
    cat "$DFS_FIXTURE_DIR/$slug.json"
    return 0
  fi
  curl -sS -u "$DFS_USER:$DFS_PASS" -H "Content-Type: application/json" \
       -X POST "$API$path" -d "$body"
}

# task-level status must be 20000
check_status() {  # <json> <label>
  local s; s="$(jq -r '.tasks[0].status_code // .status_code // 0' <<<"$1")"
  [ "$s" = "20000" ] || { echo "DataForSEO $2 failed (status $s) — skip" >&2; exit 4; }
}

SV_BODY="$(jq -n --arg kw "$KW" --argjson loc "$GLOC" --arg lang "$GLANG" '[{keywords:[$kw],location_code:$loc,language_code:$lang}]')"
G_BODY="$(jq -n --arg kw "$KW" --argjson loc "$GLOC" --arg lang "$GLANG" '[{keyword:$kw,location_code:$loc,language_code:$lang,depth:10}]')"
N_BODY="$(jq -n --arg kw "$KW" '[{keyword:$kw,location_code:2410,language_code:"ko",depth:10}]')"

SV_JSON="$(dfs_call search_volume "$SV_PATH" "$SV_BODY")" || { echo "search_volume request failed — skip" >&2; exit 4; }
check_status "$SV_JSON" "search_volume"
VOLUME="$(jq -r '.tasks[0].result[0].search_volume // 0' <<<"$SV_JSON")"
[ -n "$VOLUME" ] || VOLUME=0

G_JSON="$(dfs_call serp_google "$G_PATH" "$G_BODY")" || { echo "google serp request failed — skip" >&2; exit 4; }
check_status "$G_JSON" "google-serp"
G_COMPS="$(jq -c --arg src "$G_URL" '[.tasks[0].result[0].items[]? | select(.type=="organic") | {domain:.domain, rank:.rank_absolute, url:.url, market:"google", source_url:$src}] | .[0:10]' <<<"$G_JSON")"
G_FEATS="$(jq -c '[.tasks[0].result[0].items[]?.type] | unique' <<<"$G_JSON")"

N_COMPS='[]'; N_FEATS='[]'
if [ "$MARKET" = "kr" ] || [ "$MARKET" = "both" ]; then
  N_JSON="$(dfs_call serp_naver "$N_PATH" "$N_BODY")" || { echo "naver serp request failed — skip" >&2; exit 4; }
  check_status "$N_JSON" "naver-serp"
  N_COMPS="$(jq -c --arg src "$N_URL" '[.tasks[0].result[0].items[]? | select(.type=="organic") | {domain:.domain, rank:.rank_absolute, url:.url, market:"naver", source_url:$src}] | .[0:10]' <<<"$N_JSON")"
  N_FEATS="$(jq -c '[.tasks[0].result[0].items[]?.type] | unique' <<<"$N_JSON")"
fi

case "$MARKET" in
  kr)     MARKETS='["kr"]' ;;
  global) MARKETS='["global"]' ;;
  both)   MARKETS='["kr","global"]' ;;
esac
CAPTURED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --arg q "$KW" \
  --argjson markets "$MARKETS" \
  --argjson vol "$VOLUME" \
  --arg sv_src "$SV_URL" \
  --argjson g "$G_COMPS" \
  --argjson n "$N_COMPS" \
  --argjson gf "$G_FEATS" \
  --argjson nf "$N_FEATS" \
  --arg captured "$CAPTURED" \
  '{
     query: $q,
     markets: $markets,
     search_volume: { value: $vol, source_url: $sv_src },
     serp_competitors: ($g + $n),
     serp_features: (($gf + $nf) | unique),
     captured_at: $captured
   }' > "$OUT"

echo "OK: wrote $OUT"
```

- [ ] **Step 5: Make it executable**

Run: `chmod +x claude-plugins/growth-marketer/skills/analyze-service/scripts/dataforseo.sh`

- [ ] **Step 6: Run tests to verify they pass**

Run: `bats claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats -f dataforseo`
Expected: PASS (5/5). The `both` run validates against the schema and extracts volume 8100 + a google and a naver competitor + the `organic` feature; the `global` run yields zero naver competitors; arg/market guards exit 2.

- [ ] **Step 7: Run the full suite (regression)**

Run: `bats claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats`
Expected: all tests PASS.

- [ ] **Step 8: Commit**

```bash
git add claude-plugins/growth-marketer/skills/analyze-service/scripts/dataforseo.sh \
        claude-plugins/growth-marketer/skills/analyze-service/tests/fixtures/dfs \
        claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats
git commit -m "feat(growth-marketer): dataforseo.sh enrichment fetcher with fixture test seam (TDD)"
```

---

### Task 3: SERP-to-channel reference

**Files:**
- Create: `claude-plugins/growth-marketer/skills/analyze-service/references/serp-to-channel.md`

- [ ] **Step 1: Write the reference**

`references/serp-to-channel.md`:

```markdown
# SERP / 검색량 → 채널 가중 규칙

`seo-enrichment.json` 을 채널 점수·신호 보정에 쓰는 규칙. `channel-fit-rubric.md` 를 보완한다.

## discovery_intent (검색량 기준)
- `search_volume.value >= 1000` → `discovery_intent = high` (검색 수요 충분 → SEO/SEM 우선).
- `search_volume.value < 1000` → `discovery_intent = low` (수요 얕음 → 소셜/추천/콘텐츠로 수요 창출).

## market (SERP 우세)
- `serp_competitors` 에 `market=="naver"` 가 우세(개수·상위랭크) → KR 시장 신호 강화(`kr`).
- `market=="google"` 도메인이 글로벌 TLD 위주 → `global` 신호.
- 둘 다 의미 있으면 `both`.

## serp_features → 채널
- `shopping` / `paid` 존재 → 커머스/검색 광고(PLA, SEM) 우선순위 ↑.
- `local_pack` → 지역/지도(네이버 플레이스, Google Business) 채널 ↑.
- `video` → YouTube/숏폼 채널 ↑.
- `people_also_ask` / `featured_snippet` 다수 → 정보형 콘텐츠/SEO ↑.

## 경쟁 강도
- 상위 organic 이 대형 도메인(브랜드/포털)으로 포화 → 검색 채널 난이도 ↑, 점수 ↓ 보정.

규칙은 결정적 힌트일 뿐 — 최종 점수는 `service-profile.json` 의 전체 맥락과 함께 판단한다.
```

- [ ] **Step 2: Commit**

```bash
git add claude-plugins/growth-marketer/skills/analyze-service/references/serp-to-channel.md
git commit -m "docs(growth-marketer): serp-to-channel weighting reference"
```

---

### Task 4: analyze-service SKILL.md integration + README

**Files:**
- Modify: `claude-plugins/growth-marketer/skills/analyze-service/SKILL.md`
- Modify: `claude-plugins/growth-marketer/README.md`

- [ ] **Step 1: Replace the `## 절차` section to insert the enrichment step**

In `SKILL.md`, replace the entire `## 절차` block (steps 1–8) with the following (a new step 4 is inserted; later steps renumber to 5–9):

````markdown
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
4. **SEO enrichment (선택, DataForSEO — graceful)** — `op` CLI 가 있고 1Password 에
   `op://Employee/DataForSEO/{username,password}` 가 있으면 실행한다. positioning.category
   또는 핵심 카테고리 키워드를 쿼리로, market(kr|global|both)을 골라:
   ```bash
   bash skills/analyze-service/scripts/dataforseo.sh "<카테고리 키워드>" <kr|global|both> <slug-dir>/seo-enrichment.json
   ```
   - exit 0: `bash skills/analyze-service/scripts/validate-artifact.sh seo-enrichment <slug-dir>/seo-enrichment.json` 로 검증한 뒤
     `references/serp-to-channel.md` 규칙으로 `discovery_intent`(검색량)·`market`(Google vs Naver 우세)를
     **실측 기반 재산정**하고, 경쟁사 SERP 도메인을 evidence/differentiators 비교에 반영한다.
   - exit 3(자격증명/op 없음) 또는 exit 4(네트워크/API 오류): **skip** — 기존 추론값을 그대로 둔다.
     skill 은 키 없이도 완주한다.
5. **service-profile.json 작성** — `schemas/service-profile.schema.json` 스키마대로:
   `source_type`, icp(segment/pains/goals), positioning(value_prop/category/differentiators),
   evidence[](claim+source_url — URL·로컬 파일 경로·DataForSEO endpoint), channel_signals(product_type/market/
   price_model/target/discovery_intent). `voc[]`(quote+source_url)는 **source_type=web 일 때만
   필수**, local_dir 이면 비운다. enrichment 가 있었으면 그 사실은 evidence 의 DataForSEO source_url 로 표현한다.
6. **채널 스코어링** — `references/channel-fit-rubric.md` + (enrichment 있으면) `references/serp-to-channel.md`
   규칙으로 각 채널 0~5 점 + rationale, recommendation(primary/secondary/why) 산출 → `channel-scores.json`
   (`schemas/channel-scores.schema.json` 준수).
7. **service-brief.md 작성** — 사람이 읽는 요약(프로파일 핵심 + 추천 채널 + 근거 + enrichment 사용 여부).
8. **검증 (필수 게이트)** — 산출물을 검증한다. 실패하면 누락 필드를 채워 다시 저장.
   검증기·스키마·rubric 은 이 skill 폴더(skills/analyze-service/) 안에 있다 — Claude/Codex 양쪽 동일 상대경로.
   ```bash
   bash skills/analyze-service/scripts/validate-artifact.sh service-profile <slug-dir>/service-profile.json
   bash skills/analyze-service/scripts/validate-artifact.sh channel-scores  <slug-dir>/channel-scores.json
   # enrichment 을 수행했으면 그것도:
   bash skills/analyze-service/scripts/validate-artifact.sh seo-enrichment  <slug-dir>/seo-enrichment.json
   ```
9. **보고** — 추천 채널과 근거를 자연어로 요약하고, 저장된 파일 경로를 알린다.
   enrichment 을 skip 했으면 그 사실(자격증명 없음 등)을 명시한다.
````

- [ ] **Step 2: Update the `## 출력` section**

Replace the `## 출력` list with:

```markdown
## 출력
- `.growth-marketer/<slug>/service-profile.json` (SoT)
- `.growth-marketer/<slug>/service-brief.md`
- `.growth-marketer/<slug>/channel-scores.json`
- `.growth-marketer/<slug>/seo-enrichment.json` (DataForSEO enrichment 수행 시에만)
- `.growth-marketer/<slug>/runs/<ts>/` 스냅샷
```

- [ ] **Step 3: Update the `## 안전` section**

Replace the `## 안전` block with:

```markdown
## 안전
- web 은 chrome 읽기 전용, local_dir 은 파일시스템 읽기 전용, DataForSEO 는 읽기 전용 데이터 조회
  (이 skill 은 외부에 입력/발행하지 않음).
- DataForSEO 자격증명은 `op read` 런타임 조회만 — 평문 저장/커밋/로그 금지. 키가 없으면 enrichment 만 skip.
- 모델 호출은 OAuth/구독 CLI 만, 과금 API 키 금지(마켓 정책). SEO 데이터 API 키는 별개 범주의 사용자 시크릿.
- 다음 단계(generate-copy/channel-playbook/cro-audit)는 이 산출물을 입력으로 받는다.
```

- [ ] **Step 4: Update the skill `description` front-matter trigger line**

In the YAML front-matter `description`, append after the existing trigger examples sentence:
`"검색량·SERP 로 채널 근거 보강" 류 요청에도 DataForSEO enrichment 로 대응한다.`

- [ ] **Step 5: Update plugin README**

In `claude-plugins/growth-marketer/README.md`, in the `analyze-service` bullet, append:
`(선택) DataForSEO HTTP enrichment 으로 검색량·Google/Naver SERP 를 더해 채널 근거를 실측으로 보강 — 자격증명은 1Password(op), 없으면 자동 skip.`

- [ ] **Step 6: Verify no dangling references**

Run: `grep -n "seo-enrichment\|dataforseo\|serp-to-channel" claude-plugins/growth-marketer/skills/analyze-service/SKILL.md`
Expected: references to the new script, schema, and reference doc all present and consistent (paths under `skills/analyze-service/`).

- [ ] **Step 7: Commit**

```bash
git add claude-plugins/growth-marketer/skills/analyze-service/SKILL.md \
        claude-plugins/growth-marketer/README.md
git commit -m "feat(growth-marketer): wire optional DataForSEO enrichment into analyze-service skill"
```

---

### Task 5: Mirror to Codex marketplace

**Files:**
- Replace tree: `.agents/plugins/plugins/growth-marketer/skills/analyze-service/`

- [ ] **Step 1: Sync the skill tree (rm -rf + cp -R)**

```bash
SRC=claude-plugins/growth-marketer/skills/analyze-service
DST=.agents/plugins/plugins/growth-marketer/skills/analyze-service
rm -rf "$DST"
mkdir -p "$(dirname "$DST")"
cp -R "$SRC" "$DST"
```

- [ ] **Step 2: Verify mirror is identical**

Run: `diff -r claude-plugins/growth-marketer/skills/analyze-service .agents/plugins/plugins/growth-marketer/skills/analyze-service && echo IDENTICAL`
Expected: `IDENTICAL`.

- [ ] **Step 3: Run bats in the mirror location**

Run: `bats .agents/plugins/plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats`
Expected: all tests PASS (same count as the Claude location).

- [ ] **Step 4: Commit**

```bash
git add .agents/plugins/plugins/growth-marketer/skills/analyze-service
git commit -m "chore(growth-marketer): mirror DataForSEO enrichment to Codex skill tree"
```

---

### Task 6: Final verification + finish

**Files:** none (verification + finishing)

- [ ] **Step 1: Run bats in both locations**

```bash
bats claude-plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats
bats .agents/plugins/plugins/growth-marketer/skills/analyze-service/tests/validate-artifact.bats
```
Expected: both fully PASS.

- [ ] **Step 2: Validate all JSON contracts + marketplaces**

```bash
for f in claude-plugins/growth-marketer/skills/analyze-service/schemas/*.json \
         .claude-plugin/marketplace.json .agents/plugins/marketplace.json \
         claude-plugins/growth-marketer/.claude-plugin/plugin.json \
         .agents/plugins/plugins/growth-marketer/.codex-plugin/plugin.json; do
  jq -e . "$f" >/dev/null && echo "ok: $f" || echo "BAD JSON: $f"
done
```
Expected: every line `ok:`.

- [ ] **Step 3: Confirm no secret leakage in committed files**

Run: `git grep -nI -e "op://Employee/DataForSEO" -- 'claude-plugins/**' '.agents/**'`
Expected: only the `op://` *reference path* appears (in `dataforseo.sh` and SKILL.md) — never an actual username/password value. Confirm no base64 creds, no real password strings.

- [ ] **Step 4: Manual live smoke (HARD GATE — note explicitly)**

This is NOT automated (requires `op` login + spends DataForSEO credits). If the operator can run it:
```bash
bash claude-plugins/growth-marketer/skills/analyze-service/scripts/dataforseo.sh "headphones" global /tmp/smoke.json
bash claude-plugins/growth-marketer/skills/analyze-service/scripts/validate-artifact.sh seo-enrichment /tmp/smoke.json
```
Expected: real SERP competitors + a search volume, exit 0, schema-valid. If not run, report "live smoke 미수행" explicitly — do not claim success.

- [ ] **Step 5: Finish the branch**

Invoke `superpowers:finishing-a-development-branch`. Tests pass → present options. On merge: fast-forward/merge to `main`, then per the repo CLAUDE.md HARD RULE run `git push origin main` and confirm `git status -sb` shows no `ahead`.

---

## Notes for the implementer

- `validate-artifact.sh` already handles `x-required` (top-level + nested object) and `x-required-item` (array items) generically — do not modify it; the new schema just uses those hints.
- The `DFS_FIXTURE_DIR` seam is what makes Task 2 testable without network or `op`. In real use the env var is unset and the script uses `op read` + `curl`.
- Location codes `2410` (South Korea) and `2840` (United States) are DataForSEO standard codes. If a live smoke returns a location error, verify against `https://docs.dataforseo.com/v3/serp/google/locations/` and adjust only the two constants in `dataforseo.sh`.
- Keep all paths relative under `skills/analyze-service/` so the Claude and Codex copies are byte-identical (mirror requirement).

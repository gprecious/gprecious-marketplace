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

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
  [ "$status" -eq 1 ]
  [[ "$output" == *"positioning"* ]]
  [[ "$output" == *"source_url"* ]]
  [[ "$output" == *"channel_signals"* ]]
}

@test "missing artifact file exits 2" {
  run "$VALIDATE" service-profile "$FIX/does-not-exist.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "non-JSON artifact exits 2" {
  tmp="$(mktemp)"; printf 'not json' > "$tmp"
  run "$VALIDATE" service-profile "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 2 ]
}

@test "unknown schema name exits 2" {
  run "$VALIDATE" no-such-schema "$FIX/service-profile.valid.json"
  [ "$status" -eq 2 ]
}

@test "channel-scores valid fixture passes" {
  run "$VALIDATE" channel-scores "$FIX/channel-scores.valid.json"
  [ "$status" -eq 0 ]
}

@test "channel-scores invalid fixture fails" {
  run "$VALIDATE" channel-scores "$FIX/channel-scores.invalid.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"recommendation"* ]]
}

@test "service-profile local_dir without voc passes" {
  run "$VALIDATE" service-profile "$FIX/service-profile.localdir.valid.json"
  [ "$status" -eq 0 ]
}

@test "service-profile web without voc fails (conditional)" {
  run "$VALIDATE" service-profile "$FIX/service-profile.web-novoc.invalid.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"voc"* ]]
}

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

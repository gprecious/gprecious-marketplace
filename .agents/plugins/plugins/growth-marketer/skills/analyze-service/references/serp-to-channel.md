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

---
name: channel-playbook
description: |
  analyze-service 가 만든 service-profile.json 을 입력으로 받아 선택 채널의 운영 플레이북을 만든다.
  baked 채널 reference 를 서비스 ICP, 포지셔닝, market, price_model, discovery_intent 에 맞춰 테일러링하고
  .growth-marketer/<slug>/playbook-<channel>.md 와 검증용 playbook-<channel>.json 을 저장한다.
  "채널 플레이북", "메타 광고 어떻게 세팅", "네이버 광고 플레이북", "이 채널 운영 가이드",
  "ASO 플레이북", "SEO 콘텐츠 운영 가이드", "리타게팅 세팅" 같은 요청에 발동.
---

# channel-playbook

선택한 채널의 baked 운영 가이드를 `service-profile.json` 에 맞춰 실행 가능한 플레이북으로 변환한다.
이 skill 은 `analyze-service` 의 downstream 단계이며, 서비스 분석을 새로 수행하지 않는다.

## 입력
- 필수: `.growth-marketer/<slug>/service-profile.json`
- 필수: 채널명. 허용값:
  - `meta-ads`
  - `google-ads-uac`
  - `naver-search-gfa`
  - `aso`
  - `seo-content`
  - `retargeting`

## 절차
1. **서비스 프로파일 읽기** — `.growth-marketer/<slug>/service-profile.json` 을 읽는다.
   `source_urls`, `source_type`, `icp`, `positioning`, `evidence`, `channel_signals` 를 입력 사실로만 사용한다.
   누락되었거나 스키마가 의심되면 먼저 `analyze-service` 를 실행하라고 안내한다.
2. **채널 정규화** — 사용자가 자연어로 말한 채널을 허용값 중 하나로 매핑한다.
   예: Meta/Facebook/Instagram → `meta-ads`, Google/UAC/App campaign → `google-ads-uac`,
   네이버/파워링크/GFA → `naver-search-gfa`, 앱스토어 최적화 → `aso`.
3. **baked reference 읽기** — `references/channels/<channel>.md` 를 읽고, 해당 채널의
   타겟팅, 예산/입찰, 크리에이티브 규격, KPI, source link 를 확인한다.
4. **서비스에 맞게 테일러링** — 다음 신호를 반드시 반영한다.
   - `icp.segment`, `icp.pains`, `icp.goals` → audience, message angle, objection handling.
   - `positioning.value_prop`, `positioning.category`, `positioning.differentiators` → headline promise, creative proof.
   - `channel_signals.product_type` → 앱설치/웹전환/콘텐츠 전환 경로.
   - `channel_signals.market` → global vs kr 채널 우선순위와 언어.
   - `channel_signals.price_model` → free/freemium/subscription/paid KPI.
   - `channel_signals.discovery_intent` → search/SEO/ASO 비중과 cold prospecting 설명.
5. **Markdown artifact 작성** — `.growth-marketer/<slug>/playbook-<channel>.md` 를 만든다.
   섹션은 이 순서를 사용한다:
   - `# <Service> <Channel> Playbook`
   - `## Channel Fit`
   - `## Targeting`
   - `## Budget and Bidding`
   - `## Creative Specs`
   - `## Measurement KPIs`
   - `## Launch Checklist`
   - `## Sources`
6. **구조화 companion 작성** — 같은 디렉토리에 `.growth-marketer/<slug>/playbook-<channel>.json` 을 만든다.
   `schemas/playbook.schema.json` 의 필드를 모두 채운다:
   `channel`, `generated_at`, `service_slug`, `targeting`, `budget_guidance`, `creative_specs`, `kpis`, `tailored_from`.
   `tailored_from[]` 의 각 item 은 reference path 또는 source URL 을 `source` 에, 사용한 근거 문장을 `claim` 에 쓴다.
7. **검증 게이트** — 이 skill 폴더 기준으로 validator 를 실행한다.
   ```bash
   bash skills/channel-playbook/scripts/validate-artifact.sh playbook .growth-marketer/<slug>/playbook-<channel>.json
   ```
   실패하면 누락 필드를 채워 다시 검증한다. 검증 전 완료 보고 금지.
8. **보고** — 저장된 Markdown/JSON 경로와 핵심 KPI 2-3개만 짧게 요약한다.

## 출력
- `.growth-marketer/<slug>/playbook-<channel>.md`
- `.growth-marketer/<slug>/playbook-<channel>.json`

## 안전
- 이 skill 은 파일 작성과 로컬 검증만 한다.
- 광고 계정, 브라우저, 결제, 발행 버튼을 조작하지 않는다.
- API key, model SDK, 네트워크 호출을 사용하지 않는다.
- 출처 없는 성과 보장 표현을 쓰지 않는다. reference 또는 service-profile evidence 에 근거가 있는 claim 만 사용한다.

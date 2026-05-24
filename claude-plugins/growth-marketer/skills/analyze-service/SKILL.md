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
   `<repo-root>/.growth-marketer/<slug>/` (.growth-marketer/ 는 repo 루트 기준; 사용자 프로젝트 .gitignore 에 .growth-marketer/ 가 없으면 추가한다). `runs/<ISO8601>/` 스냅샷 디렉토리도 만든다 (UTC·초단위, 예: 2026-05-25T09:00:00Z).
2. **페이지 읽기 (chrome MCP)** — `mcp__claude-in-chrome__*` 로:
   - 메인 리스팅/랜딩: 가치제안·카테고리·기능·가격.
   - 리뷰/소셜: 실제 사용자 문장(VOC) 인용을 source URL 과 함께 수집.
   봇 차단 회피를 위해 사용자의 실제 로그인 세션을 그대로 사용(headless 금지).
3. **경쟁사 (선택, live)** — 경쟁사 URL 이 있으면 동일하게 읽고, 더 깊은 시장
   스캔이 필요하면 research-engine `/research` 를 호출한다.
   경쟁사에서 얻은 사실은 service-profile.json 의 evidence[](source_url 포함) 와 positioning.differentiators 에 반영한다(별도 파일 없음).
4. **service-profile.json 작성** — `schemas/service-profile.schema.json` 스키마대로:
   icp(segment/pains/goals), voc[](quote+source_url), positioning(value_prop/
   category/differentiators), evidence[](claim+source_url). 모든 주장에 출처 부착.
   추가로 채널 스코어링 입력인 `channel_signals` 객체(product_type/market/price_model/target/discovery_intent)를 schema 의 `channel_signals` 필드로 기록한다.
5. **채널 스코어링** — `references/channel-fit-rubric.md` 규칙으로 각 채널 0~5 점 +
   rationale, recommendation(primary/secondary/why) 산출 →
   `channel-scores.json` (`schemas/channel-scores.schema.json` 준수).
6. **service-brief.md 작성** — 사람이 읽는 요약(프로파일 핵심 + 추천 채널 + 근거).
7. **검증 (필수 게이트)** — 두 산출물을 검증한다. 실패하면 누락 필드를 채워 다시 저장:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-artifact.sh" service-profile <slug-dir>/service-profile.json
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-artifact.sh" channel-scores  <slug-dir>/channel-scores.json
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

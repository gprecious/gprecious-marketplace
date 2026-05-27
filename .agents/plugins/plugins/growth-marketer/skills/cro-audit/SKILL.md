---
name: cro-audit
description: |
  랜딩페이지, 가입 플로우, 폼, checkout, 페이월을 연결된 브라우저로 읽기 전용 점검하고
  CRO 베스트프랙티스 대비 전환 마찰을 구조화해 우선순위 개선안을 만든다.
  "전환율 점검", "랜딩 페이지 개선", "가입 퍼널 마찰", "CRO 감사", "페이월 최적화",
  "폼 이탈 줄여줘", "CTA 개선해줘" 같은 요청에 발동.
  결과는 .growth-marketer/<slug>/cro-audit-<page>.md 로 저장하고
  schemas/cro-audit.schema.json 계약을 validate-artifact.sh 로 검증한다.
---

# cro-audit

전환 퍼널 페이지를 읽기 전용으로 분석해 마찰 지점, 증거, 심각도, 개선안을 산출한다.
모든 판단은 `references/cro/` 의 baked CRO 기준과 페이지에서 관찰한 증거에 연결한다.

## 입력
- 필수: 랜딩페이지, 가입 페이지, checkout, 가격/페이월 URL 중 하나.
- 선택: 서비스 slug, 페이지 이름, 주요 전환 목표(예: signup, checkout, subscribe, demo request).

## 절차
1. **slug + page 결정** — URL host/path 또는 사용자가 준 이름에서 kebab-case slug 와 page 이름을 만든다.
   산출 루트는 `<repo-root>/.growth-marketer/<slug>/` 이며 파일명은
   `cro-audit-<page>.md` 로 둔다. run 스냅샷은 필요하면 `runs/<ISO8601>/` 에 남긴다.
2. **브라우저 읽기 전용 캡처** — `mcp__claude-in-chrome__*` 로 사용자의 실제 브라우저 세션에서
   URL을 열고 페이지를 읽는다. 링크/탭 이동은 관찰에 필요한 범위로 제한한다.
   폼 제출, 구매, 구독, 발행, 저장, 계정 변경, 결제, destructive action 은 절대 실행하지 않는다.
3. **퍼널 신호 추출** — 다음 항목을 페이지 증거와 함께 기록한다.
   - promise/message match: 광고 또는 검색 intent 와 hero headline/value prop 의 일치.
   - CTA clarity: primary CTA 문구, 반복 위치, competing CTA, next-step 명확성.
   - proof/trust: 리뷰, 고객 로고, 보안/환불/보증, social proof, objection FAQ.
   - form/signup friction: visible field 수, 필수/선택 구분, help text, 오류 예방, progressive profiling 가능성.
   - paywall/pricing: trial, plan count, monthly/annual anchor, 가격 노출, reminder/refund/guarantee wording.
   - load/mobile/navigation: 모바일에서 CTA 접근성, 레이아웃 밀도, loading 또는 destination usability 문제.
4. **CRO 기준 대조** — `references/cro/landing-signup-paywall.md` 의 기준으로 각 마찰을
   `area`, `evidence`, `severity`, `recommendation`, `reference_ids` 로 정리한다.
   severity 는 전환 결정에 직접 영향을 주면 `high`, 다음 행동을 흐리게 하면 `medium`,
   국소적 개선이면 `low` 로 둔다.
5. **우선순위화** — high severity, 전환 목표와 가까운 단계, 구현 난이도가 낮고 증거가 강한 항목을 먼저 둔다.
   각 recommendation 은 관찰 가능한 변경과 측정 지표(CTA click, form start, signup completion,
   trial start, checkout completion 등)를 포함한다.
6. **산출물 작성** — `.growth-marketer/<slug>/cro-audit-<page>.md` 에 사람이 읽는 감사 결과를 쓴다.
   문서 안에는 JSON 계약과 같은 필드(`page_url`, `captured_at`, `friction_items`)가 드러나야 한다.
   구조화 검증이 필요하면 같은 내용을 JSON으로 임시 저장해 검증한다.
7. **검증 (필수 게이트)** — 생성한 구조화 JSON 또는 fixture를 이 skill 폴더의 검증기로 확인한다.
   ```bash
   bash skills/cro-audit/scripts/validate-artifact.sh cro-audit <artifact.json>
   ```
   실패하면 누락 필드를 채워 다시 검증한다.
8. **보고** — 상위 3개 friction item, 저장 경로, 검증 결과를 요약한다.

## 출력
- `.growth-marketer/<slug>/cro-audit-<page>.md`
- 선택: `.growth-marketer/<slug>/runs/<timestamp>/cro-audit-<page>.json`

## 데이터 계약
- `page_url`: 감사 대상 URL.
- `captured_at`: ISO-8601 캡처 시각.
- `friction_items[]`: 각 항목은 `area`, `evidence`, `severity`, `recommendation` 필수.
- 권장 선택 필드: `page_type`, `summary`, `reference_ids`, `metric`, `effort`.

## 안전
- 브라우저 작업은 읽기 전용이다.
- 폼 제출, 결제, 구독 시작, 계정 변경, publish/save action, destructive click 은 금지한다.
- API keys, model API calls, 광고 플랫폼 입력은 사용하지 않는다.
- dark pattern 권장은 금지한다. 허위 희소성, 숨겨진 비용, 기만적 trial/paywall copy 는 개선 대상이다.

---
name: review-assets
description: |
  .growth-marketer/<slug>/ 아래의 service-profile.json, channel-scores.json, copy/*,
  playbook-*, cro-audit-* 산출물을 발행 전 일관성 QA로 점검한다. 브랜드 보이스,
  메시지·톤 일관성, claim/evidence 무결성, 채널 적합성, dark-pattern 위험을 검토하고
  review-checklist.md + review-checklist.json 을 만든다. "일관성 검토", "자산 QA",
  "브랜드 보이스 점검", "발행 전 체크", "리뷰 체크리스트" 같은 요청에 발동.
  이 결과는 draft-campaign 의 publish gate 이며 gate_status 가 pass 여야 다음 단계로 간다.
---

# review-assets

`review-assets`는 growth-marketer 산출물 전체를 읽어 브랜드 보이스, 메시지, 톤, 채널 적합성,
claim/evidence 무결성, CRO 준비도, dark-pattern 위험을 점검한다. 결과는 사람이 읽는
`review-checklist.md`와 검증 가능한 `review-checklist.json` companion으로 저장한다.

## 입력

- 필수: `.growth-marketer/<slug>/` 산출물 디렉토리.
- 권장 입력 파일:
  - `service-profile.json`
  - `channel-scores.json`
  - `copy/*.md` 및 있으면 `copy/*.json`
  - `playbook-*.md` 및 있으면 `playbook-*.json`
  - `cro-audit-*.md` 및 있으면 관련 JSON snapshot
  - 있으면 `campaign-draft-*.md`는 read-back consistency 참고용으로만 읽는다.

## 절차

1. **slug + artifact root 확인** — 사용자가 준 slug 또는 경로에서 `.growth-marketer/<slug>/`를 찾는다.
   디렉토리가 없으면 먼저 `analyze-service`부터 실행하라고 안내한다. 이 skill은 외부 사이트,
   브라우저, 광고 플랫폼, API를 호출하지 않는다.
2. **산출물 수집** — 아래 파일을 모두 찾고 `reviewed_artifacts[]`에 artifact 이름과 source path를 기록한다.
   ```bash
   find .growth-marketer/<slug> -maxdepth 2 -type f \
     \( -name 'service-profile.json' -o -name 'channel-scores.json' -o \
        -path '*/copy/*' -o -name 'playbook-*' -o -name 'cro-audit-*' -o \
        -name 'campaign-draft-*' \)
   ```
   필수 upstream 파일(`service-profile.json`, `channel-scores.json`)이 없으면 `gate_status="fail"`로 둔다.
3. **기준 읽기** — 이 skill 폴더의 `references/quality-standards.md`를 읽는다. 기준은
   brand voice, message clarity, claim/evidence integrity, channel fit, CRO readiness,
   experiment discipline, dark-pattern avoidance다.
4. **서비스 단일 진실 공급원 적용** — `service-profile.json`의 `icp`, `voc`, `positioning`,
   `evidence`, `channel_signals`를 기준으로 downstream artifacts를 대조한다.
   근거 없는 숫자, 후기, 고객 수, ROI, 할인, 희소성, deadline, benchmark는 claim/evidence finding으로 기록한다.
5. **artifact별 점검** —
   - `channel-scores.json`: 추천 채널과 downstream playbook/copy 채널이 맞는지 본다.
   - `copy/*`: ICP language, tone, proof, CTA, technique annotation, evidence gaps를 본다.
   - `playbook-*`: target, budget, creative specs, KPI가 channel_signals와 충돌하지 않는지 본다.
   - `cro-audit-*`: message match, CTA clarity, trust, form/paywall friction, dark-pattern avoidance를 본다.
   - `campaign-draft-*`: 있으면 field map/read-back과 reviewed copy가 일치하는지 본다.
6. **finding 작성** — 각 문제를 `artifact`, `dimension`, `severity`, `recommendation`으로 기록한다.
   severity는 `low`, `medium`, `high`, `blocking` 중 하나다. `blocking`은 unsupported factual claim,
   fake proof/scarcity, 법적·윤리적 위험, offer contradiction, 필수 artifact 누락에만 쓴다.
7. **gate_status 결정** — blocking finding이 하나라도 있거나 필수 artifact가 없어 claim/evidence 검토를
   끝낼 수 없으면 `gate_status="fail"`로 둔다. 실패한 gate는 반드시 `blocking_findings[]`를 포함한다.
   blocking이 없고 모든 reviewed artifact가 source path를 가지면 `gate_status="pass"`로 둔다.
8. **Markdown checklist 작성** — `.growth-marketer/<slug>/review-checklist.md`를 만든다.
   섹션 순서:
   - `# <Service> Review Checklist`
   - `## Gate Status`
   - `## Reviewed Artifacts`
   - `## Blocking Findings`
   - `## Findings by Dimension`
   - `## Recommended Fixes`
   - `## Evidence Gaps`
   - `## Draft-Campaign Readiness`
9. **JSON companion 작성** — `.growth-marketer/<slug>/review-checklist.json`을 만든다.
   `schemas/review-checklist.schema.json` 필드를 채운다:
   `service_slug`, `reviewed_at`, `reviewed_artifacts`, `findings`, `gate_status`.
   `gate_status="fail"`이면 `blocking_findings`도 필수다.
10. **검증 (필수 publish gate)** — 이 skill 폴더 기준으로 검증한다.
   ```bash
   bash skills/review-assets/scripts/validate-artifact.sh review-checklist .growth-marketer/<slug>/review-checklist.json
   ```
   실패하면 누락 필드를 채워 다시 검증한다. 검증 전 완료 보고나 `draft-campaign` 진행 금지.
11. **보고** — `gate_status`, blocking finding 수, 저장된 `review-checklist.md`와
   `review-checklist.json` 경로, 다음에 고칠 상위 3개 항목만 짧게 요약한다.

## 출력

- `.growth-marketer/<slug>/review-checklist.md`
- `.growth-marketer/<slug>/review-checklist.json`

## 데이터 계약

- `reviewed_artifacts[]`: 검토한 모든 입력 artifact와 source path.
- `findings[]`: `artifact`, `dimension`, `severity`, `recommendation` 필수.
- `gate_status`: `pass` 또는 `fail`.
- `blocking_findings[]`: `gate_status="fail"`일 때 필수. `draft-campaign`은 이 배열이 비어 있지 않은
  실패 gate를 publish-blocking 상태로 취급한다.

## 안전

- 파일 읽기와 checklist 작성만 수행한다.
- 브라우저, 광고 계정, 결제, publish/save action, API key, model SDK를 사용하지 않는다.
- 출처 없는 성과 보장, 허위 희소성, fake review/social proof, hidden fee, deceptive trial copy는
  반드시 blocking finding으로 기록한다.
- `draft-campaign`은 이 checklist의 `gate_status`가 `pass`일 때만 다음 단계로 진행할 수 있다.

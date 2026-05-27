---
name: generate-copy
description: |
  service-profile.json 을 바탕으로 광고 문구, CTA, 랜딩 카피, 이메일 시퀀스, 오가닉 소셜 카피를
  인지심리 기반으로 생성하고 각 변형에 technique id + source ref 를 주석으로 남긴다.
  "카피 써줘", "광고 문구 만들어", "랜딩 카피", "이메일 시퀀스", "인지심리 기반 카피",
  "A/B 카피", "전환 카피" 같은 요청에 발동. analyze-service 의 downstream skill 이다.
---

# generate-copy

`analyze-service` 가 만든 `.growth-marketer/<slug>/service-profile.json` 을 단일 진실 공급원으로 삼아
채널·자산타입별 카피를 만든다. 모든 카피는 설명 가능하고 측정 가능해야 하며, 사용한 심리 기법은
technique id 와 source ref 로 주석 처리한다.

## 입력

- 필수: `.growth-marketer/<slug>/service-profile.json`
- 필수: target channel (`meta`, `google-ads`, `naver`, `aso`, `seo`, `retargeting`, `email`, `organic-social`)
- 필수: asset type (`ad-cta`, `landing-page`, `email-sequence`, `organic-social`)
- 선택: technique selection. 사용자가 지정하지 않으면 `data/technique-index.json` 에서 channel + asset type 에 맞는 기법을 고른다.
- 선택: tone, language, offer, proof preference, sequence length, platform detail.

## 절차

1. **프로파일 읽기** — `<repo-root>/.growth-marketer/<slug>/service-profile.json` 을 읽는다.
   `icp`, `voc`, `positioning`, `evidence`, `channel_signals` 만 카피의 근거로 사용한다.
   근거가 없는 숫자, 후기, 할인, 고객수, 마감일은 만들지 않는다.
2. **자산 제약 선택** — `data/copy-templates.json` 에서 요청한 `channel` + `asset_type` 조합을 찾고
   format, constraints, variant_count 를 적용한다.
3. **기법 선택** — `data/technique-index.json` 에서 적용 가능한 기법을 고른다. 사용자가 기법을 직접
   지정했더라도 `applicable_channels`, `applicable_asset_types`, `bounds` 에 맞지 않으면 대체안을 제안한다.
4. **baked reference 적용** —
   - `references/cognitive-psychology/technique-catalog.md`: Cialdini 원칙, loss aversion, anchoring,
     scarcity/FOMO, social proof, copy formulas, A/B 측정 기준.
   - `references/frameworks/offer-positioning-email.md`: VOC/ICP, offer, positioning, hook model,
     lifecycle email.
5. **카피 생성** — `.growth-marketer/<slug>/copy/<asset>-<channel>.md` 를 만든다. Markdown 구조:
   - Source profile path
   - Channel and asset type
   - Audience / ICP
   - Template constraints applied
   - Variant A/B or email sequence branches
   - Annotation under each variant: `technique id`, `source_ref`, why it fits this profile
   - Measurement: hypothesis, primary metric, guardrail metric
   - Evidence gaps: tempting claims that were intentionally not used because evidence is missing
6. **검증용 companion 작성** — machine-readable gate 가 필요하면 같은 basename 의 JSON companion
   `.growth-marketer/<slug>/copy/<asset>-<channel>.json` 을 `schemas/copy.schema.json` 형태로 작성한다.
   Markdown 에 들어간 technique annotations 와 `technique_refs[]` 가 일치해야 한다.
7. **검증** — skill 폴더 기준으로 검증한다.
   ```bash
   bash skills/generate-copy/scripts/validate-artifact.sh copy .growth-marketer/<slug>/copy/<asset>-<channel>.json
   ```
   Skill-owned data 를 바꿨다면 아래도 함께 실행한다.
   ```bash
   bash skills/generate-copy/scripts/validate-artifact.sh copy-templates skills/generate-copy/data/copy-templates.json
   bash skills/generate-copy/scripts/validate-artifact.sh technique-index skills/generate-copy/data/technique-index.json
   ```
8. **보고** — 생성된 `.md` 경로, 선택한 기법, 측정 가설, 검증 결과를 짧게 알린다.

## 산출물

- `.growth-marketer/<slug>/copy/<asset>-<channel>.md`
- `.growth-marketer/<slug>/copy/<asset>-<channel>.json` (검증용 companion, 필요 시)

## 안전 / 가드레일

아래는 OUT OF BOUNDS 이며 생성하지 않는다.

- 허위 희소성, 가짜 countdown, "오늘만 마감"처럼 실제 근거 없는 urgency
- 존재하지 않는 waitlist, 좌석 수, beta capacity, 재고 수량
- fake review, AI-generated testimonial, 구매한 follower/view, 조작된 social proof
- 출처 없는 고객 수, 매출 수치, ROI, 절감액, benchmark, 가격 anchor
- 실제 evidence 보다 harm 을 과장하는 fear-based manipulation
- 숨겨진 비용, 자동 갱신, commitment escalation 을 흐리는 CTA

`scarcity`, `loss-aversion`, `anchoring`, `social-proof` 는 강한 기법이므로 반드시 evidence 와 함께만 사용한다.
근거가 부족하면 "권장 proof to collect" 로 분리하고 최종 카피에는 넣지 않는다.

## 데이터 계약

- `schemas/copy.schema.json`: generated copy companion artifact.
- `schemas/copy-templates.schema.json`: `data/copy-templates.json`.
- `schemas/technique-index.schema.json`: `data/technique-index.json`.
- `scripts/validate-artifact.sh`: generic validator copied from `analyze-service`.

## 다음 단계 연계

- `channel-playbook` 은 같은 service profile 과 channel 을 사용해 실행 계획을 만든다.
- `draft-campaign` 은 이 skill 의 `copy/*` 를 입력으로 받을 수 있지만 publish 는 금지된다.
- `review-assets` 는 생성된 copy, playbook, campaign draft 의 voice, evidence, consistency 를 검사한다.

---
name: draft-campaign
description: |
  generate-copy 산출물과 크리에이티브 규격을 바탕으로 Meta, Google Ads, Naver 광고
  캠페인 빌더에 DRAFT 상태로만 필드를 입력하고 campaign-draft-<channel>.md/.json을 만든다.
  "캠페인 초안 입력", "광고 세팅 초안", "메타 캠페인 드래프트", "구글 광고 초안",
  "네이버 캠페인 입력", "광고 캠페인 드래프트" 같은 요청에 발동한다.
---

# draft-campaign

`draft-campaign`은 `.growth-marketer/<slug>/copy/<asset>-<channel>.md`와 크리에이티브
규격을 읽고, 사용자의 실제 Chrome 세션에서 광고 플랫폼 캠페인 빌더에 필드를 입력한다.
입력은 반드시 draft 저장까지만 수행하며, 사람이 최종 발행 여부를 결정한다.

## PUBLISH-FORBIDDEN HARD RULE

NEVER publish. NEVER click `Publish`, `게시`, `발행`, `Launch`, `Submit for review`, 또는
동등한 의미의 버튼을 클릭하지 않는다.

허용되는 동작은 draft-save, save draft, 임시저장, 또는 입력 없이 계획을 출력하는 것뿐이다.
플랫폼이 publish/launch 버튼만 제공하고 draft-save 경로가 명확하지 않으면 즉시 중단하고
`draft_status="blocked"` 산출물을 작성한다. `draft_status="published"`는 유효한 상태가 아니며
이 skill의 산출물에 절대 쓰지 않는다.

## 입력

- 필수: `.growth-marketer/<slug>/copy/<asset>-<channel>.md`
- 권장: 같은 basename의 `.json` companion, 있으면 `generate-copy` 계약 대조에 사용한다.
- 필수: 크리에이티브 규격 또는 채널 playbook path.
- 필수: channel (`meta`, `google-ads`, `naver`)
- 필수 publish gate: `.growth-marketer/<slug>/review-checklist.json`

## 절차

1. **artifact root 확인** — `.growth-marketer/<slug>/`를 찾고 `copy/<asset>-<channel>.md`,
   크리에이티브 규격, `review-checklist.json` 경로를 확정한다.
2. **review-assets gate 확인** — `review-checklist.json`을 읽어 `gate_status == "pass"`인지
   확인한다. `gate_status`가 `pass`가 아니거나 파일이 없으면 브라우저 입력을 하지 않는다.
   `.growth-marketer/<slug>/campaign-draft-<channel>.json`에 `draft_status="blocked"`와
   `review_checklist_ref`를 기록하고 종료한다.
3. **copy + specs 로드** — copy 본문, technique annotations, CTA, headline, 설명문,
   creative specs, channel constraints를 읽는다. 근거 없는 새 claim, 새 할인, 새 수치,
   새 scarcity는 만들지 않는다.
4. **DRY-RUN field map 작성** — 실제 입력 전에 플랫폼 필드별 `field_map[]`을 계획하고 출력한다.
   예산, 결제, 입찰, 청구, 카드, daily/monthly cap 필드는 `requires_individual_confirmation=true`로
   표시하고 각각 별도 확인을 받는다.
5. **사용자 확인 전 입력 금지** — dry-run field map과 예산/결제 필드 확인이 끝나기 전에는
   `mcp__claude-in-chrome__*`로 광고 플랫폼에 값을 입력하지 않는다. 확인이 없으면
   `draft_status="planned"` 산출물만 만든다.
6. **브라우저 draft 입력** — 확인 후 사용자의 로그인 Chrome에서 캠페인 빌더를 연다.
   입력 전 screenshot ref를 저장하고, field map에 있는 값만 입력한다. publish/launch 계열
   버튼은 절대 클릭하지 않는다. draft-save 경로가 있으면 draft로만 저장한다.
7. **스크린샷 read-back** — 입력 후 screenshot ref를 저장하고 화면의 실제 값과
   `value_intended`를 대조한다. 차이는 `draft_diff[]`와 `field_map[].read_back_note`에 기록한다.
8. **산출물 작성** — 아래 두 파일을 만든다.
   - `.growth-marketer/<slug>/campaign-draft-<channel>.md`
   - `.growth-marketer/<slug>/campaign-draft-<channel>.json`
9. **검증** — skill 폴더 기준으로 JSON companion을 검증한다.
   ```bash
   bash skills/draft-campaign/scripts/validate-artifact.sh campaign-draft .growth-marketer/<slug>/campaign-draft-<channel>.json
   ```
   검증 실패 시 누락 필드를 보완하고 다시 검증한다. 검증 전 완료 보고 금지.
10. **보고** — draft 상태, review gate path/status, screenshot refs, read-back mismatch 수,
    산출물 경로를 짧게 보고한다. publish는 수행하지 않았다고 명시한다.

## 출력 Markdown 구조

`campaign-draft-<channel>.md`는 다음 섹션을 포함한다.

- `# <Service> Campaign Draft - <Channel>`
- `## Draft Status`
- `## Review Gate`
- `## Source Copy and Creative Specs`
- `## Dry-Run Field Map`
- `## Screenshot Read-Back`
- `## Draft Diff`
- `## Confirmation Checklist`
- `## Publish-Forever-Forbidden Note`

## JSON 데이터 계약

`schemas/campaign-draft.schema.json`의 companion 필드:

- `service_slug`
- `created_at`
- `channel`
- `source_copy_ref`
- `creative_specs_ref`
- `draft_status` (`planned`, `entered`, `blocked` only)
- `review_checklist_ref` (`path`, `gate_status`)
- `field_map[]` (`field`, `value_intended`, optional read-back fields)
- `screenshots` (`before`, `after`)
- `draft_diff[]`
- `confirmation_checklist[]`
- `publish_action_taken` must be `false`

## 안전

- API key, model SDK, ad platform API를 사용하지 않는다.
- 브라우저 조작은 사용자의 실제 로그인 세션에서만 수행한다.
- 결제/예산/입찰/청구 필드는 개별 확인 없이는 입력하지 않는다.
- `review-assets`의 `review-checklist.json` `gate_status`가 `pass`가 아니면 입력하지 않는다.
- publish/게시/발행/launch/submit for review 계열 동작은 어떤 경우에도 수행하지 않는다.

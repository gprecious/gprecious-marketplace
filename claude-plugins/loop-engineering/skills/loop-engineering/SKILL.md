---
name: loop-engineering
description: Use when the user wants to turn a repetitive, reviewable task into a controlled agent loop — phrases like "이거 자동화/반복하고 싶어", "루프로 돌리고 싶어", "정기적으로 점검하게 해줘", "loop engineering", "agent loop 설계", or wants to audit existing loops ("루프 점검", "loop audit"). Designs a loop with trigger·state·verification·human-gate·stop + 7 guardrails + 6 metrics, maps it onto an existing engine (herdr/loop/Cron/Workflow/Codex Automations), and writes a spec to docs/loops/. Does NOT execute loops itself and is NOT for one-off prompts (use goalcraft) or multi-agent run orchestration (use herdr/cmux).
---

# loop-engineering

반복 업무를 **루프로 만들지 판정**하고 5요소(+scope/forbidden/retry 보강)·가드레일·지표로 **설계·감사**하는 거버넌스 레이어.
**실행은 하지 않는다** — 기존 엔진(`/loop`·`/goal`·Cron·herdr·Workflow·Codex Automations 등)에 매핑만 한다.

## 핵심 원칙 (요약, 전문은 references/principles.md)

- 제품 양산 자동화 ❌. 이미 하네스 있는 반복 업무를 검증 가능한 폐쇄 루프로 감싸는 운영 설계.
- **분석은 LLM, 결정은 사람.** human gate는 넓은 scope·배포 영향·product taste 지점에만.
- 큰 fleet ❌, 검증 가능한 작은 루프 1~3개부터. 신규 루프는 `dry-run`으로 시작.

## 라우팅

사용자 의도에 따라 아래 절차를 따른다. (Claude는 `/loop-design`·`/loop-audit` 명령도 제공하지만,
명령 없이 발동했거나 Codex라면 아래 flow를 직접 실행한다.)

- **루프 설계** (반복 업무를 루프로 만들고 싶음) → `references/design-flow.md`를 읽고 그대로 수행.
- **루프 감사** (등록된 루프 점검) → `references/audit-flow.md`를 읽고 그대로 수행.

## 참조 (필요 시 읽기)

- `references/principles.md` — 정의·오해교정·triage 4기준·human gate
- `references/guardrails-and-metrics.md` — 가드레일 7종·지표 6종·stage
- `references/backend-mapping.md` — 실행엔진 선택
- `references/control-plane-adapters.md` — file/github-issue/slack-relay
- `references/catalog.md` — 우리 맥락 루프 레시피
- `references/templates/` — loop-spec·registry 템플릿

## 경계

- 단발 prompt 최적화 → goalcraft.
- 실제 병렬 실행/워커 spawn → herdr·cmux.
- 이 skill은 설계·감사·문서화까지만. 실행 트리거는 사람이 backend 명령으로 한다.

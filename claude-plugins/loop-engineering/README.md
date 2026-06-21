# loop-engineering

반복 업무를 **루프로 만들지 판정**하고, `trigger · state · verification · human gate · stop`의
5요소 + 가드레일 7종 + 지표 6종으로 **설계·등록·감사**하는 거버넌스 레이어.
**실행은 직접 하지 않는다** — herdr·`/loop`·`/goal`·Cron·Workflow·Codex Automations 등
기존 엔진에 매핑만 한다.

## 명령

- `/loop-design <반복 업무 설명>` — triage(4기준) → 통과 시 5요소·가드레일·backend·control plane을
  대화로 설계 → `docs/loops/<loop-name>/spec.md` 생성 + `registry.md` 등록.
- `/loop-audit [registry 경로]` — 등록 루프의 spec 완결성·지표·드리프트·no-op precision 점검 →
  `docs/loops/audit-<date>.md`.

자동 발동: "이 일을 자동화/반복하고 싶어", "루프로 돌리고 싶어" 류 발화 시 skill이 떠서 위 명령으로 라우팅.

## 철학

Loop engineering은 제품 양산 자동화가 아니라, 이미 하네스가 있는 반복 업무를 검증 가능한 폐쇄
루프로 감싸는 **운영 설계**다. 분석은 LLM에게, **결정(진행 여부·scope 대비 가치·리스크)은 사람에게**.
큰 fleet이 아니라 검증 가능한 작은 루프 1~3개부터.

## control plane

기본은 소비 repo의 `docs/loops/` 파일(git 커밋). `references/control-plane-adapters.md`로
GitHub Issue·Slack-relay 미러링 선택 가능.

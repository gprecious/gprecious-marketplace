# Loop Spec: <loop-name>

- stage: draft | dry-run | scheduled
- owner: <사람>
- created: <YYYY-MM-DD>
- backend: <한 개만 — /loop, /goal, Cron, herdr, Workflow, Codex Automations, prime-orchestrator (합성이면 backend-mapping 참조)>
- control-plane: file | github-issue | slack-relay

## triage (도입 판정)

- repetitive: <근거>
- reviewable: <근거>
- valuable: <근거>
- bounded-risk: <근거>
- 판정: PASS

## 5요소 + 보강 3필드

- **trigger**: <ticket | schedule | event | human request — 구체적으로>
- **state**: <지속 상태 위치/형식>
- **verification**: <센서 — 실행 가능한 명령/체크. 예: `pnpm lint` exit 0, console 에러 0. backend=/goal이면 증거를 대화에 출력>
- **human gate**: <위치 + 무엇을 결정 — 또는 "없음(저위험 자동완료)">
- **stop condition**: <done criteria — objective 우선. 주관적이면 rubric+threshold>
- **scope/boundary**: <건드릴 수 있는 범위 — repo/브랜치/경로/배포 1개 등>
- **forbidden actions**: <절대 금지 — secrets·IAM·billing·data 삭제·리뷰 없는 merge 등>
- **retry rule**: <실패 후 — 기본: 가장 작은 확인된 원인부터, 테스트 약화 금지>

## 가드레일 (7종 전부)

- max-iteration: <N>
- max-wall-clock: <시간>
- token/cost budget: <값>
- no-progress stop: <조건>
- worktree 격리: <yes/no + 방식>
- evidence log: <경로>
- rollback path: <경로>

## 지표 (추적 대상)

- first-pass closure / rework count / review time / failure catch rate / no-op precision /
  cost per useful finding 중 이 루프에 의미 있는 것 표시.

## 실행 메모

- 어떤 backend 명령으로 어떻게 트리거하는지 1~3줄.

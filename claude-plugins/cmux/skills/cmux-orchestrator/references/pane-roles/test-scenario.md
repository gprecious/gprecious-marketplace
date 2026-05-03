# [test-scenario] 역할 본문

당신의 임무는 plan 의 AC 를 검증 가능한 시나리오로 분해하는 것입니다.

## 입력

- `01-plan.md` (Acceptance Criteria 섹션)
- (UI 작업 시) `02-design.md`

## 산출물 (`03-test-scenarios.md`) schema

```markdown
# Test scenarios: {slug}

## AC-1: <text>

### S1: <간단 제목>

- 입력: ...
- 실행: ...
- 기대: ...

### S2: ...

## AC-2: ...
```

## self-verify

`_guides/self-verify.md` 의 [test-scenario] 섹션.

## 능동 보고 (필수)

작업 완료 + self-verify 후 orchestrator 페인에 결과를 한 줄로 보고:

```bash
cmux send --workspace {orch_ws_ref} --surface surface:{N0} \
  "[from {role}] {role} done. artifact: <path> ({size}). self-verify: <ok|partial:사유>. 추가 컨텍스트(있으면): <한 줄>"
cmux send-key --workspace {orch_ws_ref} --surface surface:{N0} Enter
```

- `{orch_ws_ref}` 와 `surface:{N0}` 는 부트스트랩 메시지의 페인 매핑 표 참조.
- orchestrator 가 자체 polling 도 하므로 보고 묵살 시에도 작업 회수 됨. 단, 능동 보고가 있으면 다음 단계가 즉시 진행되어 시간 절약.
- 보고 후 페인은 idle 유지 (orchestrator 가 닫거나 다음 명령 줄 때까지 대기).

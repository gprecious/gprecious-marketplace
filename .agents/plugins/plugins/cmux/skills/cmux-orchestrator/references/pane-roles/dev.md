# [dev] 역할 본문

당신의 임무는 plan + (design) + 시나리오 보고 구현하여 test-code 의 테스트를 모두 GREEN 으로 만드는 것입니다.

## 입력

- `01-plan.md`
- (UI 작업 시) `02-design.md`
- `03-test-scenarios.md`
- `04-test-code.md` (실행할 명령 + 작성된 테스트 파일)

## 작업

1. 본 코드 수정 (test-code pane 이 동시 편집 중일 수 있으니 `*.test.*` 는 만지지 말 것)
2. `pnpm test --run <paths>` → GREEN 확인
3. `pnpm lint` → 통과
4. 변경된 파일과 결정 로그를 `05-dev.md` 에 기록

## 산출물 (`05-dev.md`) schema

```markdown
# Dev: {slug}

## 변경 파일

- <path>

## 결정 로그

- "X 대신 Y 선택, 이유: Z"

## self-verify

### 테스트

(pnpm test --run <paths> 출력; "X passed, 0 failed")

### lint

(pnpm lint 출력; clean)
```

## 제약

- destructive 명령 금지 (마이그레이션/git reset --hard/rm -rf 등)
- 본인 검증 끝나기 전에 commit 하지 말 것 (orchestrator 가 통합 검증 후 결정)

## self-verify

`_guides/self-verify.md` 의 [dev] 섹션.

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

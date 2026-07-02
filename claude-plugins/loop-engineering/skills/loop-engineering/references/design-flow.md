# /loop-design 절차 (캐노니컬)

입력: 반복 업무 설명($ARGUMENTS). 산출: 소비 repo `docs/loops/<loop-name>/spec.md` + `registry.md` 1행.
이 절차는 Claude `/loop-design` 명령, skill 자동발동, Codex skill이 공통으로 따른다.

## 0. 카탈로그 매칭

사용자 입력이 `references/catalog.md`의 한 행과 유사하면 그 레시피를 출발점으로 제안한다.

## 1. Triage (도입 판정) — human gate #1

`references/principles.md`의 4기준(repetitive·reviewable·valuable·bounded-risk)을 하나씩 묻고
근거를 받는다. 하나라도 불만족이면 **루프를 만들지 않고** 사유를 설명한다:

- 단발성 → goalcraft로 단발 prompt 안내
- 큰 리스크/되돌리기 어려움 → 사람이 직접 처리 권고
  4기준 PASS여야 다음으로 진행.

## 2. 5요소 + 보강 3필드 설계 (대화형)

`templates/loop-spec.md`를 채운다. 각 요소를 한 번에 하나씩 묻는다:

1. **trigger** — ticket/schedule/event/human request 중 무엇이고 구체적 조건은?
2. **state** — 사이클 사이 무엇을 어디에 저장? (기본 file: `docs/loops/<name>/`)
3. **verification** — **실행 가능한 센서**여야 한다. "잘 됐는지 확인"이 아니라 `pnpm lint` exit 0,
   console 에러 0, 스크린샷 diff 같은 결정론적 명령. 없으면 만들 수 있는지 함께 설계.
   **backend가 `/goal`이면** 센서 결과를 에이전트가 **대화에 출력**하도록 설계한다 — 평가자(fast model)는
   파일·명령에 접근하지 못하고 transcript만 보고 판정하므로, 증거가 대화에 없으면 goal이 확정되지 않는다.
4. **human gate** — 어디에 둘지. principles.md 기준(넓은 scope·배포 영향·product taste). 저위험이면 "없음".
5. **stop condition** — objective metric 우선. 주관적이면 rubric+independent checker+threshold+hard cap 강제.

이어서 Good Goal Shape 기준 **보강 3필드**를 함께 채운다(빈칸 불가). triage·가드레일과 겹쳐 보여도,
프롬프트/spec에 명시적으로 박히는 별개 필드다:

6. **scope/boundary** — 루프가 건드릴 수 있는 범위(어느 repo·브랜치·경로·배포 1개 등). "무엇을 할 수 있나".
7. **forbidden actions** — 절대 금지 목록(secrets 커밋·IAM/billing 변경·data 삭제·리뷰 없는 merge). "무엇이 금지인가".
8. **retry rule** — 실패 후 무엇을 하나. 기본: **가장 작은 확인된 원인부터** 수정·재검증, 테스트 약화 금지.

## 3. 가드레일 7종 (빈칸 불가)

`guardrails-and-metrics.md`의 7종을 전부 값으로 채운다. 사용자가 모르면 보수적 기본값 제안
(max-iter 5, wall-clock 30m, no-progress 2회). 코드 변경 루프면 worktree 격리 yes 강제.

## 4. backend 매핑 (1개)

`backend-mapping.md` 결정표로 정확히 1개 backend 지정. 2개 이상 필요하면 루프를 쪼개라고 안내.
단, 완료가 "스케줄 트리거 + goal 수렴"의 합성이면 backend-mapping의 **합성 시스템** 절을 따른다
(예외적으로 trigger+`/goal` 2개 표기 허용, trigger·stop·human gate가 3부분을 각각 담을 것).

## 5. control plane

`control-plane-adapters.md`에서 택1. 기본 file. github-issue/slack-relay 선택 시에도 file은 유지.

## 6. 지표

루프에 의미 있는 지표(6종 중)를 표시. ops 루프면 no-op precision 필수 포함.

## 7. stage 지정

신규 루프는 `dry-run`으로 시작(스케줄 금지). no-op precision·useful finding rate 안정 후에만
`/loop-audit`이 `scheduled` 승격을 권고한다.

## 8. 산출물 쓰기 — human gate #2

완성된 spec을 사용자에게 **요약 제시**하고 승인받는다(진행 결정 전 변경 금지 원칙). 승인 후:

- 소비 repo가 어디인지 확인(현재 작업 repo. 모르면 묻는다).
- `docs/loops/<loop-name>/spec.md` 작성 (`templates/loop-spec.md` 채운 것).
- `docs/loops/registry.md` 없으면 `templates/registry.md`로 생성, 있으면 1행 추가.
- evidence 디렉토리 `docs/loops/<loop-name>/evidence/` 생성(.gitkeep).
- 커밋은 사용자 결정에 맡긴다(자동 push 금지).

## 출력 형식

끝에 다음을 요약: loop-name, stage=dry-run, backend, control-plane, 다음 행동(수동 드라이런 N회 후
/loop-audit).

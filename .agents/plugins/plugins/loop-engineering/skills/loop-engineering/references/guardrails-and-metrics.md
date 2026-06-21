# 가드레일 & 지표

## 가드레일 7종 (모든 루프 spec에 필수, 빈칸 불가)

| 가드레일          | 의미                      | 예시 값             |
| ----------------- | ------------------------- | ------------------- |
| max-iteration     | 최대 반복 횟수            | 5                   |
| max-wall-clock    | 벽시계 상한               | 30m                 |
| token/cost budget | 토큰·비용 예산            | $2 / run            |
| no-progress stop  | 진전 없으면 중단          | 2회 연속 변화 없음  |
| worktree 격리     | 코드 루프는 격리 checkout | git worktree        |
| evidence log      | 실행 증거 기록            | `evidence/<run>.md` |
| rollback path     | 되돌리기 경로             | revert PR / 미적용  |

주관적 목표 보강: rubric · independent checker · sample set · pass/fail threshold · hard cap.

## 성공 지표 6종 (agent 실행량 ❌)

루프의 성공은 "몇 번 돌았나"가 아니다.

| 지표                    | 정의                                                         |
| ----------------------- | ------------------------------------------------------------ |
| first-pass closure      | 첫 통과로 완료된 비율                                        |
| rework count            | 재작업 횟수                                                  |
| review time             | 사람 검토 소요                                               |
| failure catch rate      | 실패를 잡아낸 비율                                           |
| **no-op precision**     | "변경 없음"을 신뢰성 있게 보고하는 정확도 (false positive ↓) |
| cost per useful finding | 유용한 발견 1건당 비용                                       |

ops 루프(매일 돌아도 대부분 no-op)는 특히 **no-op precision**이 핵심. "변경 없음을 신뢰성 있게
보고하는 것"도 제품 기능처럼 취급한다.

## 도입 단계 (stage)

spec에 현재 stage를 표기한다.

| stage       | 의미              | 게이트                                      |
| ----------- | ----------------- | ------------------------------------------- |
| `draft`     | 설계만 됨         | 미실행                                      |
| `dry-run`   | 수동 트리거만     | false positive·runaway 관찰 중              |
| `scheduled` | 스케줄/inbox 연결 | no-op precision·useful finding rate 안정 후 |

# Failure recovery

## 카테고리별 정책

| 케이스                   | 감지                                       | 자동 대응                                     | critical                      |
| ------------------------ | ------------------------------------------ | --------------------------------------------- | ----------------------------- |
| Pane spawn 실패          | cmux exit code                             | 1 retry (1s 후)                               | 2회 실패                      |
| Pane dead                | capture 동일 60s + footer 없음             | pane 재spawn + 부트스트랩 재전송              | 재spawn 도 dead               |
| 모델 rate limit          | "rate limit" / "429" / "Try again in" 매칭 | 메시지 시간 파싱 → sleep → 재시도             | 60s 이상 대기 필요            |
| 모델 daily/billing 한도  | "exceeded" / "billing" / "credit" 매칭     | 즉시 critical                                 | (즉시)                        |
| 컨텍스트 ≥ 60%           | model footer token 추출                    | persistent: `/compact` 전송                   | 핵심 산출물 손실 위험 시 fork |
| 컨텍스트 ≥ 85%           | 동일                                       | 강제 fork (새 pane spawn + 부트스트랩 재주입) | 보고만 (작업 이어감)          |
| self-verify 1 retry 실패 | manifest 누적                              | 페인에 재요청                                 | retry 후 실패                 |
| 2차 검증 1 retry 실패    | manifest 누적                              | 차이 보여주고 재시도                          | retry 후 실패                 |
| 통합 테스트 3회 실패     | self-verify 결과 누적                      | dev pane 에 실패 로그 재투입                  | 3회째 실패                    |
| 사용자 강제 중단         | orchestrator 인터럽트                      | manifest 모든 stage status = paused           | 보고                          |

## 작업 재개 (resume)

orchestrator 호출 시 첫 단계:

1. feature_slug 인자 또는 task description hash 로 `.cmux-orchestrator/<slug>/manifest.json` 검사
2. 존재 + 일부 stage 가 done/paused → resume mode
   - 사용자 한 줄 보고: "이전 manifest 발견 (slug=X, plan/test-scenario done). 이어가시겠습니까?" — critical
   - done 인 stage skip
   - paused/failed stage 부터 재spawn
   - persistent pane 이 cmux tree 에 살아있으면 재사용, 죽었으면 새 spawn + 부트스트랩에 "이미 작성한 산출물 읽고 이어가라" 명시
3. 없으면 신규 워크플로우

명시적 호출: `--resume [slug]` 또는 자연어 "X 작업 재개". slug 없으면 `.cmux-orchestrator/` 스캔 후 사용자 선택.

## fork 절차

1. 새 pane spawn (같은 모델, 같은 lifecycle)
2. 부트스트랩 메시지에 추가:
   ```
   ## 이어받기
   - 이전 페인이 작성한 산출물: .cmux-orchestrator/{slug}/{artifact}.md (반드시 읽고 시작)
   - manifest.stages.{role}.status 가 running 으로 남아있을 수 있음 → 본인이 갱신
   ```
3. 이전 페인은 닫음 (`cmux close-surface`)
4. manifest.panes 의 이전 surface ref `alive=false` 마킹, 새 ref 추가

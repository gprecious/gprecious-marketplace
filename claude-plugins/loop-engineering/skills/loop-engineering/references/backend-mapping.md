# Backend 매핑 결정표

loop-engineering은 **실행하지 않는다.** 설계된 루프를 아래 엔진 중 하나에 태운다고 spec에 명시만 한다.

| 루프 성격                              | 권장 backend                              | 비고                                   |
| -------------------------------------- | ----------------------------------------- | -------------------------------------- |
| 단일 세션·간격/self-paced 폴링·solo    | Claude Code `/loop`                       | 가장 단순. 간격(cron) 또는 self-paced(턴 사이 대기) |
| 단일 세션·수렴 작업·완료를 평가자 판정 | Claude Code `/goal`                       | 매 턴 후 별도 fast model(Haiku)이 조건 판정. **평가자는 명령 실행·파일 읽기 불가 → verification 증거를 대화에 surface해야 함**. ceiling은 조건에 `or stop after N turns` |
| 정기 스케줄·백그라운드·findings inbox  | Cron(launchd/systemd) / Codex Automations | no-op 자동완료 루프                    |
| 병렬 워커·역할 분리                    | herdr / cmux                              | maker-checker·manager-with-helpers     |
| 결정론적 fan-out + verify 파이프라인   | Workflow tool                             | dimension fan-out + adversarial verify |
| 상시 가용·watchdog·failover 필요       | prime-orchestrator                        | active-active 운영 루프                |

선택 규칙:

1. 사람 게이트가 매 사이클 필요 → 스케줄 금지, solo loop + 수동 트리거.
2. 결과가 좁고 되돌리기 쉬움 + 매일 점검 → Cron/Codex Automations, no-op 자동완료.
3. 한 사이클이 여러 독립 하위작업으로 쪼개짐 → Workflow 또는 herdr.
4. 다운타임 불가 → prime-orchestrator.
5. 완료가 "조건 충족"으로 표현되고 턴 사이 대기가 불필요 → `/goal`(즉시 다음 턴 + 외부 평가자). 대기가 유용하면(빌드/PR가 시간을 두고 변함) self-paced `/loop`(Claude 자가판단).

backend는 **1개만** 지정한다. 두 개 이상이면 루프를 분리한다.

## 합성 시스템 (schedule → goal → interval-check)

단일 backend로 안 끝나는 대표 패턴: **스케줄/이벤트가 goal을 트리거하고, goal이 done(또는 blocked)될 때까지 내부에서 반복 점검**한다. 3-part:

1. 스케줄/이벤트가 작업을 시작한다(Cron / Codex Automations).
2. goal이 finish line을 정의한다(`/goal` 조건).
3. interval 점검이 done 또는 blocked까지 반복한다.

예: "매주 월요일 아침 → 최근 7일 prod 로그·CI 실패·이슈 스캔 goal → 확인된 버그면 재현·테스트·draft PR, 없으면 점검내용 no-op 보고". 이 경우에 한해 backend를 트리거(Cron/Codex Automations) + 실행(`/goal`) 둘로 표기하되, 이는 **예외적 합성**이며 spec의 trigger·stop·human gate가 세 부분을 각각 담아야 한다. 합성이 필요 없으면 위 결정표대로 backend 1개만 쓴다.

# Backend 매핑 결정표

loop-engineering은 **실행하지 않는다.** 설계된 루프를 아래 엔진 중 하나에 태운다고 spec에 명시만 한다.

| 루프 성격                             | 권장 backend                              | 비고                                   |
| ------------------------------------- | ----------------------------------------- | -------------------------------------- |
| 단일 세션·명확한 stop·solo loop       | Claude Code `/loop` 또는 `/goal`          | 가장 단순                              |
| 정기 스케줄·백그라운드·findings inbox | Cron(launchd/systemd) / Codex Automations | no-op 자동완료 루프                    |
| 병렬 워커·역할 분리                   | herdr / cmux                              | maker-checker·manager-with-helpers     |
| 결정론적 fan-out + verify 파이프라인  | Workflow tool                             | dimension fan-out + adversarial verify |
| 상시 가용·watchdog·failover 필요      | prime-orchestrator                        | active-active 운영 루프                |

선택 규칙:

1. 사람 게이트가 매 사이클 필요 → 스케줄 금지, solo loop + 수동 트리거.
2. 결과가 좁고 되돌리기 쉬움 + 매일 점검 → Cron/Codex Automations, no-op 자동완료.
3. 한 사이클이 여러 독립 하위작업으로 쪼개짐 → Workflow 또는 herdr.
4. 다운타임 불가 → prime-orchestrator.

backend는 **1개만** 지정한다. 두 개 이상이면 루프를 분리한다.

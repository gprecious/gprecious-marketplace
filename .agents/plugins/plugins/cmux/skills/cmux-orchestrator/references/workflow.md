# Workflow

## Adaptive pipeline

plan pane 의 응답에서 task_classification 을 받아 다음 분기:

```
new-feature-no-ui    → plan → test-scenario → test-code + dev (병렬) → review
new-feature-with-ui  → plan → design(A) → test-scenario → test-code + dev → design(B) → review
bugfix               → plan(축약) → test-code(failing repro) → dev → review
refactor             → plan → dev → 기존 테스트 통과 검증 → review
design-only          → design (Figma 분석/제안) → review
```

분류가 모호하면 critical → 사용자 한 줄 보고 후 진행.

## 단계 공통 패턴

```
[stage]
  1. 이전 산출물 경로를 부트스트랩에 포함하여 pane spawn 또는 재사용
  2. cmux send + Enter 로 부트스트랩 메시지 전송
  3. pane: 작업 → 산출물 파일 작성 → self-verify → manifest.stages.<role>.self_verified 갱신
  4. pane: orchestrator 에게 "<role> done" 한 줄 응답
  5. orchestrator: send-and-poll.sh 의 poll_until_idle 로 응답 수신
  6. orchestrator: 2차 검증 (산출물 schema lint, 테스트 재실행, AC 매트릭스)
     → manifest.stages.<role>.orchestrator_verified 갱신
  7. ok 면 다음 단계, 실패면 1 retry, 그래도 실패면 critical
```

## Critical decision 발동 조건 (객관적 신호만)

- pane dead (capture 동일 60s + 모델 footer 없음) — 재spawn 도 실패
- 통합 테스트 3회 연속 실패
- 모델 한도 / billing 메시지 매칭
- task 분류 불가능 (plan pane 응답 모호)
- self-verify 또는 2차 검증 1 retry 후도 실패
- design 일치도 1 retry 후도 partial/fail
- resume 모드에서 이전 manifest 발견

주관적 판정 ("scope 변경", "destructive change") 은 critical 판정 기준에서 제외 — false positive 위험.

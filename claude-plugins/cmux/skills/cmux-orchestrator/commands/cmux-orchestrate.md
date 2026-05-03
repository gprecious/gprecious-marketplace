---
description: cmux 위에서 plan/design/test/dev/review 페인을 자동 오케스트레이션해 작업 수행
---

cmux-orchestrator skill 을 발동하여 사용자 요청을 multi-pane 워크플로우로 처리한다.

## 인자

- 인자 없음: 마지막 사용자 메시지를 task description 으로 사용
- `--resume [slug]`: 재개 모드. slug 없으면 `.cmux-orchestrator/` 스캔 후 선택 (critical)
- `--here`: 새 workspace 만들지 않고 현재 cmux workspace 에 페인 추가 (기본: 새 workspace)
- `--visualization-command "<cmd>"`: UI 일치도 검증용 명령 명시 (생략 시 자동 감지)

## 호출

1. `~/.claude/skills/cmux-orchestrator/SKILL.md` 의 워크플로우 따름
2. 첫 단계: 사전 점검 → workspace 부트스트랩 → plan
3. critical decision 만 사용자 보고, 그 외 자동 진행

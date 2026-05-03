# Self-verify checklists

각 페인은 작업 완료 시 본 가이드의 자기 역할 섹션을 실행하고 결과를 `manifest.json` 의 `stages.<role>.self_verified` 에 기록한다.

기록 형식:

```json
{
  "ok": true|false,
  "checklist": ["항목1: ✓", "항목2: ✓", "항목3: ✗ (이유)"],
  "evidence": "재현 가능한 명령 또는 출력 발췌"
}
```

`scripts/manifest.sh` 의 헬퍼:

```bash
source ~/.claude/skills/cmux-orchestrator/scripts/manifest.sh
# 직접 jq 도 가능 — atomic 교체만 지킬 것.
```

## 공통 (모든 역할 마지막 단계)

- [ ] **능동 보고 송신** — orchestrator 페인에 cmux send + Enter 한 줄 보고 (`_guides/cross-pane-chat.md` 의 "능동 보고" 절차)
- [ ] 보고 후 페인 idle 유지 (orchestrator 가 다음 명령 줄 때까지 대기)

## [plan]

- [ ] AC ≥ 1
- [ ] 각 AC 가 명제 형식 ("X 한다" 가 아닌 "X 가 일어났을 때 Y 가 검증된다")
- [ ] task_classification 이 5 enum 중 하나 (`new-feature-no-ui` / `new-feature-with-ui` / `bugfix` / `refactor` / `design-only`)
- [ ] UI 분류면 figma_frame_urls ≥ 1 또는 명시적 "Figma 없음"

## [design]

A 단계 (plan 후):

- [ ] figma_frame_urls 가 비어있지 않음
- [ ] 컴포넌트 매핑 표 ≥ 1
- [ ] 토큰 매핑 표 ≥ 1
- [ ] 모든 figma frame 이 표에 1회 이상 등장

B 단계 (dev 후):

- [ ] 모든 UI 관련 AC 가 1개 이상 항목으로 다뤄짐
- [ ] match_status 가 `pass | partial | fail` 중 하나
- [ ] partial/fail 항목은 fix_hint 채워짐

## [test-scenario]

- [ ] 모든 AC 가 시나리오 ≥ 1 매핑
- [ ] 시나리오마다 입력 + 실행 + 기대 명시

## [test-code]

- [ ] 모든 시나리오 → 테스트 매핑
- [ ] 작성한 테스트를 즉시 실행해서 모두 RED 확인 (PASS 가 1개라도 있으면 fail)
- [ ] 실행 명령 04-test-code.md 에 기록 (재현 가능)

## [dev]

- [ ] 04-test-code.md 의 명령으로 테스트 실행 → 모두 GREEN
- [ ] `pnpm lint` 통과 (또는 프로젝트 lint 명령)
- [ ] 변경된 파일 list 가 05-dev.md 에 명시

## [review]

- [ ] 모든 AC 가 ✓/✗/N/A 중 하나로 표시
- [ ] 발견 이슈 0건이면 "통과" 한 줄 명시, 아니면 모든 이슈에 severity / path:line / suggestion

# goalcraft

거친 요구사항·버그 리포트·대충 적은 작업 설명을, 그 작업을 실제로 실행할 **에이전틱 코딩 도구(Claude Code 또는 OpenAI Codex)** 에 맞춘 **goal 최적화 프롬프트**로 변환하는 skill.

코딩 에이전트는 작업이 *끝난 것처럼 보이면* 멈춘다. goalcraft 는 에이전트가 스스로 검증할 수 있는 측정 가능한 goal 을 만들어, 사람이 "멈춤 신호" 역할을 하지 않아도 되게 한다.

## 핵심 동작

- **Executor-adaptive** — 스킬을 실행 중인 에이전트를 타깃으로 삼는다. Claude Code 가 실행하면 Claude 최적화(plan-first·`@file`·scope guard·`think`), Codex 가 실행하면 Codex 최적화(`Goal/Context/Constraints/Done-when` 4부 골격). 사용자가 타깃을 명시하면 그쪽을 따른다.
- **변환 전 누락 필드 질문** — 완료조건(done-when)·범위·제약·검증 명령이 빠졌으면 먼저 묻는다(없으면 명시적 가정).
- **장기작업은 `/goal`** — 마이그레이션·리팩토링 등은 Claude Code / Codex 의 실제 `/goal ... without stopping until <검증가능 종료조건>` 으로 구성.
- **복붙용 출력** — 변환된 프롬프트를 단일 코드블록으로 전달.

## 사용 예

> "이 요구사항을 codex 한테 줄 프롬프트로 변환해줘: reports 페이지에 기간별 매출 CSV 내보내기 추가"

> "대시보드 느린 거 빠르게 해달라고 코딩 에이전트한테 시킬 건데, 제대로 된 goal 프롬프트로 만들어줘"

## 구성

```
skills/goalcraft/
├── SKILL.md                  # 워크플로 (타깃 식별 → 골격 추출 → 누락 질문 → 조립 → 전달)
└── references/
    ├── claude-code.md        # Claude Code 프로필 (plan mode, /goal, thinking, scope guard)
    └── codex.md              # Codex 프로필 (Goal/Context/Constraints/Done-when, /goal, AGENTS.md)
```

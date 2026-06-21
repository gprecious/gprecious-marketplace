# loopcraft

반복·주기적 작업 설명을 **Claude Code `/loop` 용 프롬프트**로 변환하는 skill. **goalcraft 의 loop 형제** — goalcraft 가 단발 goal 프롬프트를 만들듯, loopcraft 는 반복 `/loop` 프롬프트를 만든다.

코딩 에이전트는 작업이 *끝난 것처럼 보이면* 멈춘다. 단발에선 한 번 헛도는 비용이지만, **루프**에선 runaway 가 된다 — 매 iteration 마다 "끝났다"를 다시 선언하거나, 영영 멈추지 않는다. 좋은 `/loop` 프롬프트는 사람을 "멈춤 신호"에서 빼낸다: 에이전트가 스스로 확인하는 **객관적 종료조건**, 폭주를 막는 **iteration ceiling**, 매 회 근거를 남기는 **verification 센서**를 박는다.

## 핵심 동작

- **모드 판정이 1차 분기** — `/loop` 실제 동작과 1:1로 매핑한다.
  - `fixed-interval` (`/loop 5m <task>`) — 정기 폴링·스케줄(cron 변환, 7일 자동 만료)
  - `self-paced` (`/loop <task>`, 간격 생략) — 종료조건 있는 수렴 작업. Claude 가 1분~1시간 자가 페이싱, **provably complete 면 스스로 종료**
  - `loop.md-default` (`.claude/loop.md` 본문) — 브랜치/PR 상시 유지보수
- **변환 전 누락 필드 질문** — 객관적 종료조건·ceiling·verification·interval 이 빠졌으면 먼저 묻는다(없으면 명시적 가정). 우선순위 1번은 늘 **종료조건**.
- **항상 적용되는 강제규칙 6종** — 객관적 종료(주관 금지) · iteration ceiling · 매 회 verification · 이전 상태 참조 · 고위험 단계 human gate · noisy 작업의 single-trial 판정 금지.
- **복붙용 출력** — 변환된 `/loop` 명령(또는 `loop.md` 본문)을 단일 코드블록으로, 상단에 모드 라벨과 함께 전달.

## 경계 (3자 분업)

- **단발 1회** → `goalcraft`
- **반복 `/loop` 프롬프트** → **loopcraft** (이 스킬)
- **루프로 만들지 판정 + 5요소 설계·감사** → `loop-engineering`

`/loop` 은 Claude Code 고유 기능이라 loopcraft 는 **Claude Code 전용**이다(Codex 미지원).

## 사용 예

> "preview 배포되면 콘솔 에러 점검 계속 돌려줘. /loop 프롬프트로 만들어줘"

> "CI 통과하고 리뷰 코멘트 다 처리될 때까지 반복하는 /loop 으로 만들어줘"

> "이 브랜치 PR 계속 돌봐주는 loop 만들어줘"

## 구성

```
skills/loopcraft/
├── SKILL.md                  # 워크플로 (모드 판정 → 골격 추출 → 누락 질문 → 조립 → 전달)
├── references/
│   ├── loop-modes.md         # 3모드 작성 프로필 (fixed-interval / self-paced / loop.md)
│   └── recipes.md            # 종료조건 문장 패턴 + few-shot 레시피 + 안티패턴
└── evals/
    └── evals.json            # 트리거·변환·라우팅 eval
```

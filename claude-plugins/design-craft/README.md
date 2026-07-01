# design-craft

프론트엔드 UI를 **"더 나은 디자인 + anti-slop"** 으로 만드는 **decision-first** 스킬. Claude Code / Codex 공용.

> 좋은 디자인은 **취향이 아니라 결정**이다. 모델이 타이포·색·레이아웃·surface 유형·모션·카피를 *이 브리프에 맞게* 결정하지 못하면, 훈련 데이터의 고빈도 패턴으로 수렴한다 — 그게 "AI slop"이다. **slop은 못생김이 아니라 결정의 부재**다.

이 스킬은 그 결정을 강제한다. Anthropic `frontend-design` 방법론 + surface 라우터 + 수치화된 craft 기준(WCAG·타이포·색·모션) + 이름 붙인 anti-slop banlist + 렌더 스크린샷 검증 루프의 종합이다.

## 무엇이 다른가

- **surface가 먼저다** — direction보다 `marketing | functional app | dashboard | mobile | hybrid` 분류가 앞선다. 대시보드에 마케팅 취향을 바르면 그것도 slop.
- **fundamentals가 수치화** — line length 45–75ch, contrast ≥4.5:1, 4/8 spacing, target 44px, motion은 transform/opacity까지 체크 가능.
- **anti-slop이 감점축이 아니라 build gate** — banlist tell 2개 이상이면 리워크.
- **rendered output이 진실** — source가 아니라 데스크톱/태블릿/모바일 스크린샷으로 평가.
- **과교정도 slop** — weird/maximal/glass/luxury-editorial 도피를 막고 "one real risk"만 허용.

## 6 게이트 워크플로우

0. **surface 분류** — 유형별로 최적화 대상이 다르다
1. **design-decision pass** (코드 이전) — subject·audience·job·visual thesis·token system·signature·anti-defaults
2. **발산 → 수렴** — 열린 화면/hero/signature는 3–5안 후 1안 선택
3. **anti-default critique** — `references/banlist.md`로 기본 룩 탈출 (3대 AI 기본 룩 경고 포함)
4. **build** — 토큰 파생, boldness 한 곳, 카피=재료, craft 바닥선
5. **verify** — `references/verification.md`의 스크린샷 critic 게이트 (통과 못하면 완료 차단)

## 구조

```
skills/design-craft/
├── SKILL.md                    # 6 게이트 워크플로우 (host-neutral) + Claude/Codex 발동법
└── references/
    ├── fundamentals.md         # 타이포·색·스페이싱·위계·레이아웃·모션 규칙 + surface 플레이북
    ├── banlist.md              # AI-slop 카탈로그 7종 + 탈출 기법 + 과교정 가드
    └── verification.md         # 브라우저 게이트 + screenshot critic 프롬프트 + 품질표 + 리워크 루프
```

progressive disclosure — 메인 SKILL.md는 워크플로우만, 딥한 표는 게이트가 지시할 때 references를 연다.

## 사용

- **Claude Code**: `/design-craft` 또는 description 자동 발동. Gate 5는 claude-in-chrome / dev server / Playwright 스크린샷.
- **Codex**: 자동 선택이 불확실하므로 UI 작업 시 이 SKILL.md를 먼저 읽거나 `/goal`로 지정. repo 상시 규칙은 `AGENTS.md`에 craft 바닥선을 미러. `~/.agents/skills/design-craft/SKILL.md`에 사본을 두면 discovery 가능.

## 경계

- 순수 로직/백엔드 등 시각 표면이 없는 작업엔 발동 안 함.
- 사용자가 정확한 시각 스펙/디자인 시스템을 준 경우 → **그대로 구현**(스타일과 싸우지 않음). craft 바닥선·검증은 유지.

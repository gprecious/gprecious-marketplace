---
name: e2e-harness
description: |
  Use when the user wants to add or generate an E2E / verification test harness for a
  project — especially "에이전트가 작성·검증·자가수정하는" Playwright E2E for web apps
  (Next.js/Vite/Remix/SvelteKit), or a verification-harness methodology for non-web
  (CLI/API). Detects the stack, picks a recipe, co-authors critical flows with the user,
  scaffolds config+seed+specs+heal docs, and runs the harness. Works in Claude Code and Codex.
---

# e2e-harness

대상 프로젝트의 스택을 감지해 맞춤 E2E/검증 하네스를 대화형으로 생성·실행한다.
방법론 핵심은 `constitution.md`(harness-engineering 5원칙)이고, 스택별 구현은
`recipes/<recipe>.md` + `recipes/templates/<recipe>/` 로 찍어낸다.

**Cross-CLI 보장:** 이 스킬은 Claude 전용 호출이나 내장 자동화 도구를 쓰지 않는다.
아래 모든 단계는 이식성 있는 bash 다 — Codex 도 같은 SKILL.md 를 읽고 같은 bash 를 그대로 실행한다.

이 SKILL.md 가 있는 디렉터리를 `$SKILL` 로 둔다(`lib/`, `recipes/`, `constitution.md` 가 그 아래 있다).
대상 프로젝트 경로를 `$TARGET` 로 둔다(웹 앱이면 보통 `apps/web` 같은 패키지 루트).

## 1. 시작 알림
사용자에게 한 줄로 알린다: "스택 감지 → 레시피 선택 → 크리티컬 플로우 합의 → 하네스 생성 → 실행+heal."
먼저 `constitution.md` 를 읽어 5원칙을 이 작업의 기준으로 삼는다.

## 2. 스택 감지
```bash
bash "$SKILL/lib/detect-stack.sh" "$TARGET"
```
출력 JSON(`framework,dbLayer,testRunner,monorepo,locales,recipe`)을 사용자에게 그대로 보여준다.

## 3. 레시피 확인
descriptor 의 `recipe` 값(`nextjs-supabase` | `generic-web-playwright` | `_fallback`)을 사용자에게 확인받는다.
해당 `recipes/<recipe>.md` 를 읽어 변수와 레이어링 규칙을 파악한다. 감지가 애매하면 사용자가 레시피를 바꿀 수 있게 한다.

## 4. 크리티컬 플로우 Q&A (헌법 ①)
사용자에게 한 번의 질문으로 묻는다: "이 중 실패하면 매출/데이터/신뢰가 깨지는 플로우는 무엇인가?"
레포에서 후보를 찾아 목록으로 제시한다(웹이면 `app/`·`pages/`·라우터 파일에서 라우트, 비웹이면 주요 명령/엔트리포인트).
사람이 고른 플로우만 하네스 대상으로 삼는다. 통제 불가 외부 서비스는 제외한다(헌법 ②).

## 5. 하네스 생성
선택한 레시피의 변수를 채워 scaffold 한다:
```bash
bash "$SKILL/lib/scaffold.sh" --recipe <recipe> --target "$TARGET" \
  --var port=3100 --var locales=ko,en   # 레시피별 변수는 recipes/<recipe>.md 참고
```
- nextjs-supabase: `port`, `locales`, `supabaseEnv`, `externalAdDomains`, `criticalRoutes`, `healthRoute`.
- generic-web-playwright: `devCommand`, `baseUrl`, `externalDomains`(선택), `seedCommand`(선택).
- _fallback: `testRunner`, `runCommand`.

레이어링 규칙(헌법 ②): 브라우저에서 직접 부르는 외부 의존성은 `page.route` 인터셉트,
SSR/BFF 가 서버에서 부르는 외부 의존성은 환경변수 고정 응답.

## 6. 실행 + heal 루프 (헌법 ④·⑤)
웹 레시피:
```bash
cd "$TARGET" && pnpm test:e2e   # 또는 npx playwright test
```
비웹(_fallback): 생성된 `VERIFICATION-HARNESS.md` 의 실행 명령(`runCommand`)을 돌린다.

실패하면 heal 루프를 돈다:
1. trace/스크린샷/비디오 아티팩트를 연다(`npx playwright show-trace ...`).
2. 셀렉터·대기를 고친다 — 시맨틱 셀렉터(getByRole 등), 조건 기반 대기, 고정 sleep 금지.
3. 통과할 때까지 반복한다.
4. 머지 전 번인(같은 스펙을 여러 번 반복 실행)으로 플래키가 없음을 확인한 뒤에야 "완료"라 선언한다(추정 금지).

## 7. 보고
- 생성/수정한 파일 목록.
- 그린 증거 — 추정이 아니라 실제 테스트 통과 출력.
- 다음에 하네스화할 만한 크리티컬 플로우 1개를 제안한다.

---
참조: `constitution.md`(5원칙), `recipes/<recipe>.md`(스택별 변수·레이어링 규칙).
이 스킬은 Claude Code 와 Codex 양쪽에서 동일한 bash 로 동작한다.

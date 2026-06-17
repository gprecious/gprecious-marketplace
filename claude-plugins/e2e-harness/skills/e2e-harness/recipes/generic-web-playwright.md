# 레시피: generic-web-playwright

프레임워크 비종속 웹 앱(Next.js/Vite/Remix/SvelteKit 등, Supabase 결합 없음)용 Playwright E2E 하네스.
`constitution.md` 의 5원칙을 그대로 따른다.

## 감지 마커

`detect-stack.sh` 가 `framework ∈ {nextjs, vite, remix, sveltekit}` 이면서 nextjs+supabase 조합이 아닐 때 선택된다 (`recipe == "generic-web-playwright"`).

## 변수

| 변수 | 필수 | 의미 |
|------|------|------|
| `devCommand` | 필수 | dev 서버 기동 명령 (예: `npm run dev`, `pnpm dev --port 5173`). `playwright.config` 의 `webServer.command`. |
| `baseUrl` | 필수 | dev 서버 주소 (예: `http://127.0.0.1:5173`). `baseURL` 및 `webServer.url`. |
| `externalDomains` | 선택 | 브라우저에서 직접 호출하는 차단 대상 외부 호스트(쉼표 구분). 미지정 시 광고/분석 기본셋으로 폴백. |
| `seedCommand` | 선택 | 결정론적 상태가 필요하면 프로젝트가 정의하는 시드 명령. 이 레시피는 시딩을 프로젝트에 위임한다. |

## 레이어링 규칙 (헌법 원칙 ②)

- 브라우저에서 직접 부르는 외부 의존성(광고/분석/서드파티 위젯) → `page.route` 로 인터셉트(`e2e/fixtures.ts` 의 `isolateExternal`).
- SSR/BFF 가 서버에서 부르는 외부 의존성 → 환경변수로 고정 응답(프로젝트별). 이 레시피는 DB 계층을 가정하지 않는다.

## 시딩 (헌법 원칙 ③)

결정론적 상태가 필요하면 `seedCommand` 로 프로젝트의 멱등 시드를 호출하거나, 스펙별 fixtures 로 주입한다. 기본 `smoke` 스펙은 DB-free 라 시딩이 필요 없다.

## 생성

```bash
bash skills/e2e-harness/lib/scaffold.sh --recipe generic-web-playwright \
  --target <project-dir> \
  --var devCommand="npm run dev" --var baseUrl="http://127.0.0.1:5173" \
  [--var externalDomains="googlesyndication.com,google-analytics.com"]
```

생성 후 `smoke.spec.ts` 의 예시 assertion(heading 존재 등)을 프로젝트의 실제 크리티컬 플로우로 교체한다(헌법 원칙 ①·④).

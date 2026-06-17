# 레시피: nextjs-supabase

Next.js(App Router) + Supabase 웹 앱용 Playwright E2E 하네스. fuelai 의 검증된 하네스(`apps/web/e2e/`)를
일반화한 것이며 이 레시피의 골든 레퍼런스다. `constitution.md` 5원칙을 그대로 구현한다.

## 감지 마커
`detect-stack.sh` 출력이 `framework=="nextjs" && dbLayer=="supabase"` 일 때 선택된다(`recipe=="nextjs-supabase"`).

## 변수
| 변수 | 치환/문서 | 의미 |
|------|-----------|------|
| `port` | 템플릿 치환(`{{port}}`) | dev 서버 포트. `playwright.config.ts` 의 기본 PORT. |
| `locales` | 문서 | i18n 로케일(예: `ko,en`). 스펙의 로케일 라우팅/assertion 텍스트를 이에 맞춰 교체한다. |
| `supabaseEnv` | 문서 | 시드가 쓰는 Supabase 자격 환경변수(`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`). `seed.ts`/CI 가 참조. |
| `externalAdDomains` | 문서 | 브라우저에서 차단할 외부 광고/분석 도메인. `fixtures.ts` 의 `isolateExternalAds` 정규식(헌법 ②). |
| `criticalRoutes` | 문서 | 하네스화할 크리티컬 라우트(예: `/`, `/[locale]/feed/[id]`). 스펙으로 커버한다(헌법 ①). |
| `healthRoute` | 문서 | DB-free readiness 라우트(`/api/health`). webServer.url 이 이것으로 기동을 판정한다. |

> `port`/`locales` 외 변수는 자동 치환이 아니라 "consumer 가 프로젝트에 맞춰 편집할 지점"이다.
> 특히 `seed.ts` 의 테이블/컬럼명(`raw_items`, `curated_entries` 등)은 이 레시피의 문서화된 가정이며,
> 스키마가 다르면 시드 테이블/컬럼을 프로젝트에 맞게 교체한다. 스펙(`smoke`/`ads`/`feed-detail`)의
> 로케일·assertion 텍스트(`ko`/`en`, "기술 스택" 등)도 replace-me 예시다.

## 레이어링 규칙 (헌법 ②)
- 브라우저에서 직접 부르는 외부 의존성(AdSense/분석) → `fixtures.ts` 의 `isolateExternalAds` 로 `page.route` 인터셉트.
- SSR/BFF 가 서버에서 부르는 외부 의존성(Supabase) → `global-setup.ts` 의 도달성 게이트 + 환경변수 고정.
- 통제 불가 외부 서비스는 테스트하지 않는다.

## 결정론적 시딩 (헌법 ③)
`seed.ts` 가 PostgREST 로 fixture 를 멱등 upsert 하고 `global-teardown.ts` 가 복원한다.
`global-setup.ts` 가 Supabase 도달성을 확인하고 `.fixtures.json` 을 쓴다(미도달이면 스펙이 명확한 사유로 skip).

## 생성
```bash
bash skills/e2e-harness/lib/scaffold.sh --recipe nextjs-supabase \
  --target <project-web-dir> --var port=3100 --var locales=ko,en
```
생성물: `playwright.config.ts`, `e2e/{global-setup,global-teardown,seed,fixtures}.ts`,
`e2e/{smoke,ads,feed-detail}.spec.ts`, `e2e/README.md`, `src/app/api/health/route.ts`, `ci/e2e.yml`.
생성 후 위 "consumer 편집 지점"을 프로젝트에 맞춰 조정하고, 실행+heal(헌법 ④·⑤)로 그린을 확인한다.

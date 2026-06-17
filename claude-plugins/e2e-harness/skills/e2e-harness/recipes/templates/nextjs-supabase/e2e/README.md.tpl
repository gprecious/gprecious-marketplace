# fuelai E2E 하네스 (Playwright)

AI 에이전트가 **직접 작성·검증·자가수정**하는 E2E 테스트 환경. NAVER ENGINEERING DAY 2026
발표 "AI 에이전트를 위한 Playwright E2E 테스트 하네스 구축하기"의 원칙을 fuelai web 앱에
적용했다. 배경/근거: `research/2026-06-17-ai-agent-playwright-e2e-test-harness/README.md`.

## 설계 원칙 (발표 → 이 레포)

1. **크리티컬 유저 플로우만** — "실패하면 매출/데이터/신뢰가 깨지는" 곳만 본다.
   현재 커버: 홈 진입·로케일 라우팅(신뢰), 광고 슬롯 렌더(매출), 피드 상세·404(데이터).
2. **통제 가능한 것만 테스트** — 브라우저가 직접 부르는 외부 의존성(AdSense/분석)은
   `page.route()` 로 가로채 네트워크를 격리한다(`fixtures.ts`의 `isolateExternalAds`).
   서버사이드 Supabase 호출은 브라우저를 거치지 않으므로 `global-setup`의 도달성 게이트로
   다룬다(없으면 데이터 의존 스펙 skip — 거짓 실패 방지).
3. **플래키는 작성 단계에서** — 시맨틱 셀렉터(role+name), 조건 기반 대기(web-first
   assertion, 고정 sleep 금지), 머지 전 번인(`test:e2e:burnin` = `--repeat-each=5`).

## 구조

```
e2e/
  global-setup.ts     # Supabase 도달성 확인 + 결정론적 fixture 멱등 시드(seed.ts 호출)
  global-teardown.ts  # 시드 행 제거 → 로컬 dev DB 를 테스트 전 상태로 복원
  seed.ts             # PostgREST upsert/delete — 발행 feed/stack/report 를 고정 id/key 로 주입
  fixtures.ts         # test 확장: AdSense 네트워크 격리, fixture 로더, requireSupabase 가드
  smoke.spec.ts       # #1 홈 골격 + 로케일 라우팅(/ → /ko, /en)
  ads.spec.ts         # #2 광고 슬롯(매출) — 사이드바 격리 + 리포트 multiplex
  feed-detail.spec.ts # #3 피드 상세 렌더 + 없는 id 404
  .fixtures.json      # global-setup 산출(gitignore)
playwright.config.ts  # webServer(pnpm dev :3100) + trace/screenshot 보존
```

## 데이터 시딩 (발표의 "API 상태 시딩")

`global-setup` 이 매 실행 시작에 `seed.ts`의 `seedFixtures()` 로 결정론적 행을 **멱등 upsert**한다
(고정 id `2222…`/slug `e2e-stack`/key `e2e-report`). 덕분에 상세·multiplex 플로우가 데이터 유무와
무관하게 항상 같은 시작 상태에서 검증된다. `global-teardown` 이 끝에 이 행들을 제거해 로컬
dev DB 를 테스트 전 상태로 되돌린다(앱 화면에 e2e 데이터가 남지 않음). 시드가 실패하면(예: DB
미마이그레이션) 해당 스펙만 fixture 없음으로 skip 하고 나머지는 그대로 검증한다.

## 실행

```bash
# 0) 전제: 로컬 Supabase 가 떠 있고 마이그레이션이 적용돼 있어야 한다.
pnpm db:start            # (repo 루트) supabase 기동
pnpm db:reset            # 스키마/시드 적용 (컬럼 불일치 시)
# apps/web/.env.local 에 SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 설정(= `supabase status`)

# 1) 실행 (dev 서버는 playwright 가 자동 기동/재사용)
cd apps/web
pnpm test:e2e            # 전체
pnpm test:e2e:ui         # UI 모드(작성/디버깅)
pnpm test:e2e:burnin     # 머지 전 번인(플래키 조기 탐지)
pnpm test:e2e:report     # 직전 실행 HTML 리포트
pnpm test:e2e:codegen    # 새 플로우 녹화(초안 생성)
```

Supabase 가 미도달이면 데이터 의존 스펙은 **skip**(거짓 실패 아님). 발행 데이터가 비어 있으면
상세/multiplex 스펙은 fixture 없음으로 skip 하고, 홈 골격·사이드바 광고·404 는 그대로 검증된다.

## 에이전트 워크플로 (Planner → Generator → Healer)

발표의 3종 분업을 사람+에이전트 협업으로 매핑한다:

- **Planner (사람+에이전트)** — 새 크리티컬 플로우를 고른다. 기준: 실패 시 매출/데이터/신뢰가
  깨지는가? `pnpm test:e2e:codegen` 으로 상호작용을 녹화해 초안을 얻는다.
- **Generator (에이전트)** — 초안을 이 디렉터리 규약으로 다듬는다: `fixtures.ts`의 `test`
  사용, 시맨틱 셀렉터(`getByRole`), `isolateExternalAds`로 외부 격리, 데이터 필요 시
  `requireSupabase()`/`loadFixtures()` 가드. 고정 sleep 금지(web-first assertion 사용).
- **Healer (에이전트)** — 실패 시 trace 로 원인을 진단한다. trace 는 `test-results/`에
  보존된다(`trace: retain-on-failure`). 명령:

  ```bash
  pnpm exec playwright show-trace test-results/<...>/trace.zip
  # 또는 마지막 HTML 리포트에서 trace 열기
  pnpm test:e2e:report
  ```

  Healer 는 trace 의 네트워크/DOM 스냅샷을 읽어 셀렉터·대기 조건을 고치고, **머지 전**
  `pnpm test:e2e:burnin` 으로 재발 방지를 확인한다.

## fuelai 하네스의 다른 구성요소 (발표의 "모델 가중치 외부의 모든 것")

이 E2E 는 검증 슬롯 하나일 뿐이다. 레포의 다른 하네스: `.agents/skills/*`(수집/발견 스킬),
`wiki/`(LLM 위키·도메인 지식), `vitest`(단위/통합 검증). E2E 는 이들과 함께 "에이전트가
작업 → 검증 → 실패 시 자가수정" 폐회로를 이룬다.

## TODO / 확장 여지

- **CI** — `.github/workflows` 미구성. supabase 서비스 + `pnpm test:e2e`(retries=1) 추가 시
  머지 게이트로 활용.
- **시드 확장** — 현재 시드는 기본 경로(피드 1건·리포트 1건·스택 1건)만. 콘텐츠 타입별·
  is_stale/popular_rank 등 librarian 상태 변형을 `seed.ts` 에 추가하면 더 넓은 회귀를 잡는다.
- **인증/스토리지 상태** — 로그인 플로우가 생기면 `storageState` 픽스처로 분리.

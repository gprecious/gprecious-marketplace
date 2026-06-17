import { defineConfig, devices } from "@playwright/test";

// E2E 하네스 — "AI 에이전트가 직접 작성·검증·자가수정하는 Playwright E2E" (NAVER D2 발표 원칙 적용).
// 원칙: ①크리티컬 유저 플로우만 ②통제 가능한 것만 테스트(외부 의존성은 모킹) ③플래키는 작성 단계에서.
// research/2026-06-17-ai-agent-playwright-e2e-test-harness/README.md 참고.

const PORT = Number(process.env.E2E_PORT ?? {{port}});
const BASE_URL = process.env.E2E_BASE_URL ?? `http://127.0.0.1:${PORT}`;

// 테스트 전용 AdSense 자격값 — 광고 슬롯이 결정론적으로 렌더되도록 webServer 에 주입한다.
// 실제 광고 스크립트(googlesyndication)는 각 테스트에서 page.route 로 차단해 네트워크를 격리한다.
const E2E_ADSENSE = {
  GOOGLE_ADSENSE_CLIENT: process.env.GOOGLE_ADSENSE_CLIENT ?? "ca-pub-0000000000000000",
  GOOGLE_ADSENSE_SLOT: process.env.GOOGLE_ADSENSE_SLOT ?? "1234567890",
  GOOGLE_ADSENSE_MULTIPLEX_SLOT: process.env.GOOGLE_ADSENSE_MULTIPLEX_SLOT ?? "0987654321",
};

export default defineConfig({
  testDir: "./e2e",
  // 작성 단계 안정성 게이트: 로컬에서 플래키는 즉시 드러나도록 retry 0.
  // CI 에서는 인프라성 불안정만 1회 흡수(진짜 플래키는 burn-in 스크립트로 머지 전 차단).
  retries: process.env.CI ? 1 : 0,
  forbidOnly: !!process.env.CI,
  fullyParallel: true,
  reporter: process.env.CI
    ? [["github"], ["html", { open: "never" }]]
    : [["list"], ["html", { open: "never" }]],
  // 전역 셋업: Supabase 도달성 확인 + 결정론적 fixture 멱등 시드. teardown 으로 정리.
  globalSetup: "./e2e/global-setup.ts",
  globalTeardown: "./e2e/global-teardown.ts",
  timeout: 30_000,
  expect: { timeout: 7_000 },
  use: {
    baseURL: BASE_URL,
    locale: "ko-KR",
    // 실패 진단을 에이전트(Healer)가 프로그래매틱하게 읽을 수 있도록 trace/스크린샷/비디오 보존.
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
  ],
  // 앱을 직접 띄운다(통제 가능한 환경). {{port}} 포트로 dev 서버를 올리되, 이미 떠 있으면 재사용.
  webServer: {
    command: "pnpm dev --port " + PORT,
    // readiness 는 DB-free 헬스 라우트로 판정 — 데이터가 비어/깨져 있어도 서버 기동을 감지한다.
    url: `${BASE_URL}/api/health`,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: {
      ...E2E_ADSENSE,
      // 광고/분석 외부 스크립트가 dev 서버 자체를 느리게 하지 않도록 Next 텔레메트리 비활성.
      NEXT_TELEMETRY_DISABLED: "1",
    },
  },
});

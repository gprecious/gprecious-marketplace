import { defineConfig, devices } from "@playwright/test";

// generic-web-playwright 레시피 — harness-engineering 헌법 적용.
// 프레임워크 비종속: webServer 는 프로젝트의 dev 명령으로, baseURL/url 은 그 서버 주소로 채운다.

const BASE_URL = process.env.E2E_BASE_URL ?? "{{baseUrl}}";

export default defineConfig({
  testDir: "./e2e",
  // 작성 단계 안정성 게이트: 로컬 retry 0, CI 만 인프라성 불안정 1회 흡수.
  retries: process.env.CI ? 1 : 0,
  forbidOnly: !!process.env.CI,
  fullyParallel: true,
  reporter: process.env.CI
    ? [["github"], ["html", { open: "never" }]]
    : [["list"], ["html", { open: "never" }]],
  timeout: 30_000,
  expect: { timeout: 7_000 },
  use: {
    baseURL: BASE_URL,
    // 실패 진단을 에이전트(Healer)가 읽도록 trace/스크린샷/비디오 보존.
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
  ],
  // 앱을 직접 띄운다(통제 가능한 환경). 이미 떠 있으면 재사용.
  webServer: {
    command: "{{devCommand}}",
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});

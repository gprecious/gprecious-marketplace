import { test, expect, requireSupabase, isolateExternalAds } from "./fixtures.ts";

// 크리티컬 유저 플로우 #1 — 홈 진입 + 로케일 라우팅.
// "실패하면 신뢰가 깨지는" 첫 화면: 헤더/내비/푸터 골격과 i18n 리다이렉트가 살아 있어야 한다.
test.describe("home & locale routing", () => {
  test.beforeEach(async ({ page }) => {
    requireSupabase(); // 홈은 SSR Supabase 의존 — 미도달이면 의미 있는 검증 불가라 skip.
    await isolateExternalAds(page); // 외부 광고/분석 스크립트 네트워크 격리(플래키 제거).
  });

  test("/ 는 기본 로케일 /ko 로 보낸다", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveURL(/\/ko(\/|$|\?)/);
    await expect(page.locator("html")).toHaveAttribute("lang", "ko");
  });

  test("홈 골격(헤더·내비·푸터·H1)이 렌더된다", async ({ page }) => {
    await page.goto("/ko");
    await expect(page.getByRole("banner")).toBeVisible();
    await expect(page.getByRole("navigation")).toBeVisible();
    await expect(page.getByRole("contentinfo")).toBeVisible();
    // 시맨틱 셀렉터: 클래스가 아니라 H1 역할 + 번역 텍스트로 고정.
    await expect(page.getByRole("heading", { level: 1 })).toContainText("기술 스택");
  });

  test("/en 은 영어 로케일로 렌더된다", async ({ page }) => {
    await page.goto("/en");
    await expect(page.locator("html")).toHaveAttribute("lang", "en");
    await expect(page.getByRole("heading", { level: 1 })).toContainText("tech stacks");
  });
});

import { test, expect, requireSupabase, loadFixtures, isolateExternalAds } from "./fixtures.ts";

// 크리티컬 유저 플로우 #2 — 광고 렌더(매출 직결).
// 발표 기준 "실패하면 매출이 막히는" 흐름: 슬롯 마크업이 올바른 client/slot 으로 떠야 하고,
// 실제 광고 스크립트는 page.route 로 격리해 네트워크에 의존하지 않는다.
test.describe("adsense slots (revenue-critical)", () => {
  test.beforeEach(() => requireSupabase());

  test("홈 사이드바 광고 슬롯이 올바른 client/slot 으로 렌더되고 외부 스크립트는 격리된다", async ({ page }) => {
    const blocked = await isolateExternalAds(page);
    await page.goto("/ko");

    const slot = page.locator(".ad-slot--sidebar");
    await expect(slot).toBeVisible();
    await expect(slot).toHaveAttribute("aria-label", "Advertisement");

    const ins = slot.locator("ins.adsbygoogle");
    await expect(ins).toHaveAttribute("data-ad-client", /^ca-pub-\d+$/);
    await expect(ins).toHaveAttribute("data-ad-slot", /.+/);
    await expect(ins).toHaveAttribute("data-ad-format", "auto");

    // 헤드의 AdsenseScript(googlesyndication) 요청이 실제로 가로채졌는지 확인 → 네트워크 비의존.
    expect(blocked.some((u) => u.includes("googlesyndication.com"))).toBeTruthy();
  });

  test("리포트 상세는 multiplex 광고 슬롯을 렌더한다", async ({ page }) => {
    const { reportSlug } = loadFixtures();
    test.skip(!reportSlug, "발행된 report 가 없어 multiplex 슬롯 검증 불가(데이터 시드 필요).");
    await isolateExternalAds(page);
    await page.goto(`/ko/reports/${reportSlug}`);

    const slot = page.locator(".ad-slot--multiplex");
    await expect(slot).toBeVisible();
    await expect(slot.locator("ins.adsbygoogle")).toHaveAttribute("data-ad-format", "autorelaxed");
  });
});

import { test, expect, requireSupabase, loadFixtures, isolateExternalAds } from "./fixtures.ts";

// 크리티컬 유저 플로우 #3 — 피드 상세 진입 + 없는 항목 404 처리.
// "데이터가 날아가거나 신뢰가 깨지는" 경로: 유효 항목은 본문이 뜨고, 없는 항목은 깔끔히 404.
test.describe("feed detail", () => {
  test.beforeEach(async ({ page }) => {
    requireSupabase();
    await isolateExternalAds(page);
  });

  test("발행된 피드 항목 상세가 렌더된다", async ({ page }) => {
    const { feedId } = loadFixtures();
    test.skip(!feedId, "발행된 curated_entry 가 없어 상세 검증 불가(데이터 시드 필요).");

    const res = await page.goto(`/ko/feed/${feedId}`);
    expect(res?.status()).toBeLessThan(400);
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expect(page.getByRole("contentinfo")).toBeVisible();
  });

  test("존재하지 않는 피드 id 는 404 를 반환한다", async ({ page }) => {
    // well-formed 하지만 존재하지 않는 UUID → maybeSingle null → notFound().
    const res = await page.goto("/ko/feed/00000000-0000-0000-0000-000000000000");
    expect(res?.status()).toBe(404);
  });
});

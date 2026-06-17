import { test, expect, isolateExternal } from "./fixtures.ts";

// 크리티컬 플로우 #1 — 앱 첫 화면 렌더(프레임워크 비종속, DB 불필요).
// 헌법 원칙 ①: 아래 assertion 은 예시다. 프로젝트의 실제 매출/데이터/신뢰 크리티컬 플로우로 교체할 것.
test.describe("smoke: app shell renders", () => {
  test.beforeEach(async ({ page }) => {
    await isolateExternal(page); // 외부 광고/분석 스크립트 네트워크 격리(플래키 제거).
  });

  test("루트가 로드되고 기본 골격이 보인다", async ({ page }) => {
    const res = await page.goto("/");
    expect(res?.status() ?? 200).toBeLessThan(400);
    // 시맨틱 셀렉터(클래스 금지): body 가시 + 최소 한 개의 heading 역할.
    await expect(page.locator("body")).toBeVisible();
    await expect(page.getByRole("heading").first()).toBeVisible();
  });
});

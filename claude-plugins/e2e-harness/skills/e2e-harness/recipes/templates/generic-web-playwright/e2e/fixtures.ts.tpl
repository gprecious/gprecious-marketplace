import { test as base, type Page } from "@playwright/test";

// 헌법 원칙 ②: 브라우저에서 직접 호출하는 외부 의존성은 page.route 로 인터셉트해 격리한다.
// {{externalDomains}} = 차단할 외부 호스트(쉼표 구분). 미지정(플레이스홀더 미치환)이면 광고/분석 기본셋으로 폴백.
const RAW_DOMAINS = "{{externalDomains}}";
const EXTERNAL_DOMAINS = (RAW_DOMAINS.includes("{{")
  ? "googlesyndication.com,googletagservices.com,doubleclick.net,google-analytics.com,googletagmanager.com"
  : RAW_DOMAINS)
  .split(",")
  .map((d) => d.trim())
  .filter(Boolean);

// 외부 광고/분석 스크립트를 가로채 빈 응답(204)으로 만들어 네트워크 의존·플래키를 제거한다.
export async function isolateExternal(page: Page): Promise<string[]> {
  const blocked: string[] = [];
  if (EXTERNAL_DOMAINS.length === 0) return blocked;
  const escaped = EXTERNAL_DOMAINS.map((d) => d.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
  const pattern = new RegExp(escaped.join("|"));
  await page.route(pattern, (route) => {
    blocked.push(route.request().url());
    return route.fulfill({ status: 204, contentType: "application/javascript", body: "" });
  });
  return blocked;
}

export const test = base;
export { expect } from "@playwright/test";

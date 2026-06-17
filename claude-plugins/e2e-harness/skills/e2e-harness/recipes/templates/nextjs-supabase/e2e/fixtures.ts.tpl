import { test as base, type Page } from "@playwright/test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import type { E2EFixtures } from "./global-setup.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));

export function loadFixtures(): E2EFixtures {
  try {
    return JSON.parse(readFileSync(join(__dirname, ".fixtures.json"), "utf8")) as E2EFixtures;
  } catch {
    return { supabaseReachable: false, feedId: null, reportSlug: null, stackSlug: null, reason: "fixtures 미생성" };
  }
}

// 발표 원칙: "브라우저에서 직접 호출하는 외부 의존성은 page.route 로 모킹한다."
// AdSense/분석 스크립트를 가로채 빈 응답으로 만들어 네트워크 의존·플래키를 제거한다.
// (서버사이드 Supabase 호출은 브라우저를 거치지 않으므로 여기서 막지 않는다 — global-setup 의
//  도달성 게이트가 그 레이어를 담당한다.)
export async function isolateExternalAds(page: Page): Promise<string[]> {
  const blocked: string[] = [];
  await page.route(
    /googlesyndication\.com|googletagservices\.com|doubleclick\.net|google-analytics\.com|googletagmanager\.com/,
    (route) => {
      blocked.push(route.request().url());
      return route.fulfill({ status: 204, contentType: "application/javascript", body: "" });
    },
  );
  return blocked;
}

// supabase 가 필요한 스펙 본문에서 한 줄로 가드. 미도달이면 명확한 사유로 skip.
export function requireSupabase(): E2EFixtures {
  const fx = loadFixtures();
  base.skip(!fx.supabaseReachable, `Supabase 미도달 — ${fx.reason ?? "global-setup 참고"}`);
  return fx;
}

export const test = base;
export { expect } from "@playwright/test";

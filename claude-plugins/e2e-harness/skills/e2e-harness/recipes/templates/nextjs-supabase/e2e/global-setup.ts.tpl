import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { seedFixtures } from "./seed.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));
export const FIXTURES_PATH = join(__dirname, ".fixtures.json");

export interface E2EFixtures {
  // Supabase(PostgREST)에 도달 가능한가. false 면 데이터 의존 스펙은 전부 skip 한다.
  supabaseReachable: boolean;
  // 기존 발행 데이터에서 읽어온 결정론적 대상(없으면 null → 해당 detail 스펙 skip).
  feedId: string | null;
  staleFeedId: string | null;   // is_stale=true 변형
  reportSlug: string | null;
  stackSlug: string | null;
  reason?: string;
}

// Playwright global-setup 은 Next 와 별개 프로세스라 .env.local 을 자동 로드하지 않는다.
// 최소 파서로 SUPABASE 자격값을 process.env → apps/web/.env.local → repo .env.local 순으로 찾는다.
function loadEnvVar(name: string): string | undefined {
  if (process.env[name]) return process.env[name];
  const candidates = [join(__dirname, "..", ".env.local"), join(__dirname, "..", "..", "..", ".env.local")];
  for (const file of candidates) {
    try {
      for (const line of readFileSync(file, "utf8").split("\n")) {
        const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
        if (m && m[1] === name) return m[2].replace(/^["']|["']$/g, "").trim();
      }
    } catch {
      /* 파일 없음 — 다음 후보 */
    }
  }
  return undefined;
}

async function restSelect(
  url: string,
  key: string,
  path: string,
): Promise<Record<string, unknown>[] | null> {
  try {
    const res = await fetch(`${url}/rest/v1/${path}`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` },
      // 도달성 확인용 짧은 타임아웃 — Supabase 가 죽어 있으면 빠르게 skip 으로 떨어진다.
      signal: AbortSignal.timeout(4000),
    });
    if (!res.ok) return null;
    return (await res.json()) as Record<string, unknown>[];
  } catch {
    return null;
  }
}

function write(fixtures: E2EFixtures): void {
  writeFileSync(FIXTURES_PATH, JSON.stringify(fixtures, null, 2));
}

export default async function globalSetup(): Promise<void> {
  const url = loadEnvVar("SUPABASE_URL");
  const key = loadEnvVar("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !key) {
    const reason = "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 미설정 (apps/web/.env.local).";
    console.warn(`[e2e] ${reason} → 데이터 의존 스펙 skip. \`pnpm db:start\` 후 .env.local 설정 권장.`);
    write({ supabaseReachable: false, feedId: null, staleFeedId: null, reportSlug: null, stackSlug: null, reason });
    return;
  }

  // 도달성 + fixture 를 한 번에: 발행된 feed/report/stack 의 첫 행을 읽는다(읽기 전용).
  const feed = await restSelect(url, key, "curated_entries?select=id&published=eq.true&limit=1");
  if (feed === null) {
    const reason = `Supabase 도달 실패(${url}). \`pnpm db:start\` 로 로컬 DB 기동 필요.`;
    console.warn(`[e2e] ${reason} → 전체 스펙 skip.`);
    write({ supabaseReachable: false, feedId: null, staleFeedId: null, reportSlug: null, stackSlug: null, reason });
    return;
  }

  // 발표의 "API 상태 시딩": 상세/리포트 플로우가 항상 같은 시작 상태에서 출발하도록 결정론적
  // 행을 멱등 주입한다. 시드 실패는 치명적이지 않게 — 해당 스펙은 fixture 없음으로 skip 한다.
  let fixtures: E2EFixtures;
  try {
    const seeded = await seedFixtures(url, key);
    fixtures = { supabaseReachable: true, ...seeded };
  } catch (err) {
    console.warn(`[e2e] 시드 실패(데이터 의존 스펙 skip): ${(err as Error).message}`);
    // 시드가 안 되면 기존 발행 데이터라도 fixture 로 시도.
    const [reports, stacks] = await Promise.all([
      restSelect(url, key, "reports?select=report_key&status=eq.published&limit=1"),
      restSelect(url, key, "stack_items?select=slug&status=eq.published&limit=1"),
    ]);
    fixtures = {
      supabaseReachable: true,
      feedId: (feed[0]?.id as string) ?? null,
      staleFeedId: null,
      reportSlug: (reports?.[0]?.report_key as string) ?? null,
      stackSlug: (stacks?.[0]?.slug as string) ?? null,
    };
  }
  console.log(
    `[e2e] Supabase OK — feedId=${fixtures.feedId ?? "—"} reportSlug=${fixtures.reportSlug ?? "—"} stackSlug=${fixtures.stackSlug ?? "—"}`,
  );
  write(fixtures);
}

// E2E 결정론적 시드 — 발표의 "테스트용 API 로 상태를 미리 세팅" 원칙.
// PostgREST 로 멱등 upsert(고정 id/slug/key + on_conflict)해 상세/리포트 플로우가 데이터
// 유무와 무관하게 항상 같은 시작 상태에서 출발하게 한다. global-setup 이 호출, global-teardown 이 제거.

// 고정 식별자(멱등). 다른 데이터와 충돌하지 않도록 e2e 전용 값.
export const SEED = {
  rawId: "11111111-1111-4111-8111-111111111111",
  rawStaleId: "11111111-1111-4111-8111-1111111111fe",
  feedId: "22222222-2222-4222-8222-222222222222",
  staleFeedId: "22222222-2222-4222-8222-2222222222fe",
  stackSlug: "e2e-stack",
  reportKey: "e2e-report",
} as const;

interface SeedResult {
  feedId: string;
  staleFeedId: string;
  reportSlug: string;
  stackSlug: string;
}

function headers(key: string, extra: Record<string, string> = {}): Record<string, string> {
  return { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json", ...extra };
}

async function upsert(
  url: string,
  key: string,
  table: string,
  onConflict: string,
  rows: Record<string, unknown>[],
): Promise<Record<string, unknown>[]> {
  const res = await fetch(`${url}/rest/v1/${table}?on_conflict=${onConflict}`, {
    method: "POST",
    headers: headers(key, { Prefer: "resolution=merge-duplicates,return=representation" }),
    body: JSON.stringify(rows),
    signal: AbortSignal.timeout(8000),
  });
  if (!res.ok) throw new Error(`seed ${table}: ${res.status} ${await res.text()}`);
  return (await res.json()) as Record<string, unknown>[];
}

async function del(url: string, key: string, table: string, filter: string): Promise<void> {
  await fetch(`${url}/rest/v1/${table}?${filter}`, {
    method: "DELETE",
    headers: headers(key, { Prefer: "return=minimal" }),
    signal: AbortSignal.timeout(8000),
  }).catch(() => {});
}

// 발행된 feed 항목(+raw_item, +published stack) 과 발행 리포트를 멱등 주입한다.
export async function seedFixtures(url: string, key: string): Promise<SeedResult> {
  // raw_item 은 sources(FK) 가 필요 — 시드된 source 하나를 빌려 쓴다.
  const srcRes = await fetch(`${url}/rest/v1/sources?select=id&limit=1`, {
    headers: headers(key),
    signal: AbortSignal.timeout(4000),
  });
  const sources = (await srcRes.json()) as { id: string }[];
  const sourceId = sources?.[0]?.id;
  if (!sourceId) throw new Error("seed: sources 가 비어 raw_item 을 만들 수 없음 (pnpm db:reset 필요).");

  const now = new Date().toISOString();

  await upsert(url, key, "raw_items", "id", [
    {
      id: SEED.rawId,
      source_id: sourceId,
      external_id: "e2e-fixture-1",
      url: "https://example.com/e2e-fixture",
      title: "E2E fixture raw item",
      published_at: now,
    },
  ]);
  await upsert(url, key, "raw_items", "id", [
    {
      id: SEED.rawStaleId,
      source_id: sourceId,
      external_id: "e2e-fixture-stale",
      url: "https://example.com/e2e-fixture-stale",
      title: "E2E stale raw item",
      published_at: now,
    },
  ]);

  const [stack] = await upsert(url, key, "stack_items", "slug", [
    {
      slug: SEED.stackSlug,
      name: "E2E Stack",
      category: "dev_tool",
      summary_ko: "E2E 테스트용 스택 항목입니다.",
      status: "published",
    },
  ]);

  await upsert(url, key, "curated_entries", "id", [
    {
      id: SEED.feedId,
      raw_item_id: SEED.rawId,
      stack_item_id: (stack?.id as string) ?? null,
      title_ko: "E2E 피드 상세 항목",
      summary_ko: "이 항목은 Playwright E2E 상세 플로우 검증용 결정론적 시드입니다.",
      original_lang: "en",
      content_type: "release",
      llm_meta: {},
      published: true,
    },
  ]);
  await upsert(url, key, "curated_entries", "id", [
    {
      id: SEED.staleFeedId,
      raw_item_id: SEED.rawStaleId,
      stack_item_id: null,
      title_ko: "E2E 구버전 피드 항목",
      summary_ko: "is_stale 변형 — librarian 상태 회귀 검증용.",
      original_lang: "en",
      content_type: "tutorial",
      llm_meta: {},
      published: true,
      is_stale: true,
    },
  ]);

  await upsert(url, key, "reports", "report_key", [
    {
      report_key: SEED.reportKey,
      model_slug: "e2e-model",
      title_ko: "E2E 리포트",
      summary_ko: "Playwright E2E multiplex 광고 슬롯 검증용 결정론적 리포트입니다.",
      verdict_ko: "테스트용",
      body: [{ heading: "개요", markdown: "E2E 본문 섹션." }],
      sources: [],
      status: "published",
      report_kind: "trend_deep",
    },
  ]);

  return { feedId: SEED.feedId, staleFeedId: SEED.staleFeedId, reportSlug: SEED.reportKey, stackSlug: SEED.stackSlug };
}

// 시드 제거 — 로컬 dev DB 를 테스트 전 상태로 되돌린다(테스트 행이 앱에 남지 않게).
export async function teardownFixtures(url: string, key: string): Promise<void> {
  // curated_entries 는 raw_items 삭제 시 cascade 되지만 명시적으로 먼저 지운다.
  await del(url, key, "curated_entries", `id=eq.${SEED.feedId}`);
  await del(url, key, "curated_entries", `id=eq.${SEED.staleFeedId}`);
  await del(url, key, "reports", `report_key=eq.${SEED.reportKey}`);
  await del(url, key, "raw_items", `id=eq.${SEED.rawId}`);
  await del(url, key, "raw_items", `id=eq.${SEED.rawStaleId}`);
  await del(url, key, "stack_items", `slug=eq.${SEED.stackSlug}`);
}

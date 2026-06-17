// 가벼운 헬스 체크 — DB/외부 의존성을 건드리지 않는다.
// E2E 하네스(playwright.config.ts webServer.url)의 readiness 프로브로 쓰여, dev 서버 기동을
// 앱 데이터 상태와 분리한다(DB가 비어/깨져 있어도 서버 자체는 떴다고 판정 → 120s 행 방지).
export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export function GET() {
  return Response.json({ ok: true }, { status: 200 });
}

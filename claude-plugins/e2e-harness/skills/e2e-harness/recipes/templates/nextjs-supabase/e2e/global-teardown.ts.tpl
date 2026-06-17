import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { teardownFixtures } from "./seed.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));

// global-setup 과 동일한 자격 해석(process.env → apps/web/.env.local → repo .env.local).
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
      /* 다음 후보 */
    }
  }
  return undefined;
}

// 시드 행을 제거해 로컬 dev DB 를 테스트 전 상태로 되돌린다(앱 화면에 e2e 데이터가 남지 않게).
export default async function globalTeardown(): Promise<void> {
  const url = loadEnvVar("SUPABASE_URL");
  const key = loadEnvVar("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return;
  await teardownFixtures(url, key);
  console.log("[e2e] 시드 정리 완료.");
}

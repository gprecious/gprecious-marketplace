import { defineConfig, devices } from "@playwright/test";
const PORT = Number(process.env.E2E_PORT ?? {{port}});
// ...rest copied from apps/web/playwright.config.ts with locales {{locales}}
export default defineConfig({ testDir: "./e2e", use: { baseURL: `http://127.0.0.1:${PORT}` }, projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }] });

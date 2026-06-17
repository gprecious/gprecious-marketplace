name: e2e

on:
  pull_request:
    paths:
      - "apps/web/**"
      - "packages/**"
      - "supabase/**"
      - ".github/workflows/e2e.yml"
  workflow_dispatch: {}

jobs:
  playwright:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4
        with:
          version: 11

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm

      - name: Install deps
        run: pnpm install --frozen-lockfile

      - name: Start Supabase
        uses: supabase/setup-cli@v1
        with:
          version: latest
      - run: supabase start

      - name: Resolve Supabase creds
        id: sb
        run: |
          echo "url=$(supabase status -o env | grep API_URL | cut -d= -f2 | tr -d '\"')" >> "$GITHUB_OUTPUT"
          echo "key=$(supabase status -o env | grep SERVICE_ROLE_KEY | cut -d= -f2 | tr -d '\"')" >> "$GITHUB_OUTPUT"

      - name: Install Playwright browser
        run: pnpm --filter @fuelai/web exec playwright install --with-deps chromium

      - name: Run E2E (retries=1 in CI via config)
        working-directory: apps/web
        env:
          CI: "1"
          SUPABASE_URL: ${{ steps.sb.outputs.url }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ steps.sb.outputs.key }}
        run: pnpm test:e2e

      - name: Upload report on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: apps/web/playwright-report/
          retention-days: 7

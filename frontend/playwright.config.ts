import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: [["list"], ["html", { open: "never" }]],
  globalTeardown: "./e2e/global-teardown.ts",
  use: {
    baseURL: "http://localhost:3001",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: [
    {
      command:
        "uv run --directory ../backend alembic upgrade head && uv run --directory ../backend uvicorn app.main:app --port 8001",
      env: { USE_TEST_DATABASE: "true" },
      url: "http://localhost:8001/api/health",
      timeout: 60_000,
      reuseExistingServer: false,
    },
    {
      command: "npm run build && npm run start -- -p 3001",
      env: { NEXT_DIST_DIR: ".next-e2e", BACKEND_URL: "http://localhost:8001" },
      url: "http://localhost:3001",
      timeout: 180_000,
      reuseExistingServer: false,
    },
  ],
});

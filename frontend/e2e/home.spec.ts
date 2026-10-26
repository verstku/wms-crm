import { expect, test } from "@playwright/test";

const TITLE = "Система управления складом";

test("shows the title and a running backend", async ({ page }) => {
  await page.goto("/");

  await expect(page).toHaveTitle(TITLE);
  await expect(page.locator("html")).toHaveAttribute("lang", "ru");
  await expect(
    page.getByRole("heading", { level: 1, name: TITLE }),
  ).toBeVisible();
  await expect(page.getByText("Бэкенд: работает")).toBeVisible();
});

test("shows unavailable backend when health returns 503", async ({ page }) => {
  await page.route("**/api/health", (route) =>
    route.fulfill({ status: 503, json: { status: "error", db: "error" } }),
  );
  await page.goto("/");

  await expect(page.getByText("Бэкенд: недоступен")).toBeVisible();
});

test("shows unavailable backend when the connection fails", async ({
  page,
}) => {
  await page.route("**/api/health", (route) => route.abort());
  await page.goto("/");

  await expect(page.getByText("Бэкенд: недоступен")).toBeVisible();
});

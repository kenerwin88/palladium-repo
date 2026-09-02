import { expect, test } from '@playwright/test';

test('serves the Angular shell and the live Flask contract', async ({ page, request }) => {
  await page.goto('/release/deep-link');
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Shipping should feel');
  await expect(page.getByText('LIVE SYSTEM')).toBeVisible();
  await expect(page.locator('.metadata')).not.toContainText('dev');

  const health = await request.get('/healthz');
  expect(health.ok()).toBeTruthy();
  expect(await health.json()).toMatchObject({ status: 'ok' });
});

test('has no unexpected browser errors', async ({ page }) => {
  const errors: string[] = [];
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto('/');
  await expect(page.getByText('LIVE SYSTEM')).toBeVisible();
  expect(errors).toEqual([]);
});

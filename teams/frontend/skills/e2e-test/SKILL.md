# E2E Test Generator

Generates Playwright end-to-end tests for critical user journeys based on the feature being developed.

## Steps

1. **Identify the feature scope**
   Review the changed files to understand the user journey:
   ```bash
   git diff --name-only main...HEAD
   ```
   Read the changed components and pages to understand the flow.

2. **Determine test scenarios**
   For the identified feature, define test cases covering:
   - **Happy path**: The primary user journey from start to completion.
   - **Validation errors**: Required fields, invalid input, boundary values.
   - **Error states**: Network failures, API errors, timeout handling.
   - **Edge cases**: Empty states, maximum input lengths, special characters.

3. **Generate Playwright test file**
   Create the test in `tests/e2e/` following these patterns:

   ```typescript
   import { test, expect } from "@playwright/test";

   test.describe("Feature Name", () => {
     test("should complete the happy path", async ({ page }) => {
       await page.goto("/feature-path");

       // Interact using accessible selectors
       await page.getByRole("button", { name: "Action" }).click();
       await page.getByLabel("Field Name").fill("value");

       // Assert visible outcomes
       await expect(page.getByText("Success message")).toBeVisible();
     });
   });
   ```

4. **Selector strategy**
   - Prefer accessible selectors: `getByRole`, `getByLabel`, `getByText`, `getByPlaceholder`.
   - Use `getByTestId` only when no accessible selector exists.
   - Never use CSS selectors or XPath.

5. **Test isolation**
   - Each test must be independent. Use `test.beforeEach` for common setup.
   - Mock API responses with `page.route()` for deterministic tests.
   - Clean up any created state in `test.afterEach`.

6. **Assertions**
   - Assert user-visible outcomes, not DOM structure.
   - Use `toBeVisible()`, `toHaveText()`, `toHaveURL()` over `toHaveAttribute()`.
   - Wait for network idle or specific elements rather than arbitrary timeouts.

## Output

Generate the complete Playwright test file and explain:
- What user journeys are covered.
- What API calls are mocked and why.
- How to run the tests: `npx playwright test tests/e2e/<test-file>.spec.ts`.

# E2E Tests

Runs Playwright end-to-end tests against the deployed or local application.

## Steps

1. **Check if Playwright is installed**
   ```bash
   npx playwright --version || npx playwright install chromium
   ```

2. **Determine target URL**
   - If `BASE_URL` env var is set, use it.
   - Otherwise, start the local dev server:
     ```bash
     npm run dev &
     DEV_PID=$!
     sleep 5
     BASE_URL="http://localhost:3000"
     ```

3. **Run E2E tests**
   ```bash
   BASE_URL="$BASE_URL" npx playwright test
   ```

4. **Report results**
   If tests fail, read the HTML report:
   ```bash
   npx playwright show-report
   ```

5. **Clean up**
   If a local dev server was started, stop it.

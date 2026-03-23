<!-- claude-hub:fragment:begin — This section is managed centrally. Do not edit manually. Run /hub-fragment-update to update. -->
# React Serverless — Toolchain Reference

## Commands

### Frontend Development
```bash
npm run dev                        # Start Vite dev server
npm run build                      # Production build
npm run lint                       # ESLint check
npm run typecheck                  # TypeScript type checking
npm test                           # Jest + React Testing Library
npm test -- --run                  # Run tests once (no watch)
npx playwright test                # Playwright E2E tests
```

### BFF Lambda (Backend for Frontend)
```bash
sam build                          # Build BFF Lambda functions
sam local start-api                # Start local API on port 3001
sam deploy                         # Deploy BFF to AWS
pytest tests/                      # Test BFF Lambda handlers
```

### Full Deploy
```bash
npm run build && sam build && sam deploy    # Build and deploy everything
aws s3 sync dist/ s3://$BUCKET --delete    # Sync static assets to S3
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```

## Project Structure

```
.
├── template.yaml              # SAM template (BFF Lambdas + S3 + CloudFront)
├── samconfig.toml             # SAM deploy configuration
├── package.json               # Frontend dependencies and scripts
├── vite.config.ts             # Vite configuration
├── tsconfig.json              # TypeScript configuration
├── src/
│   ├── components/            # React components (co-located with tests)
│   │   └── Button/
│   │       ├── index.tsx
│   │       ├── Button.test.tsx
│   │       └── Button.module.css
│   ├── hooks/                 # Custom React hooks (use*.ts)
│   ├── api/                   # API client functions (one file per domain)
│   ├── types/                 # Shared TypeScript interfaces
│   ├── pages/                 # Page components / routes
│   └── utils/                 # Frontend utilities
├── bff/
│   ├── handlers/              # BFF Lambda handlers (Python)
│   ├── services/              # BFF business logic
│   └── utils/                 # BFF shared helpers
├── tests/
│   ├── e2e/                   # Playwright E2E tests
│   └── bff/                   # BFF Lambda unit tests (pytest + moto)
├── public/                    # Static assets
└── dist/                      # Build output (deployed to S3)
```

## Component Patterns

- Functional components with hooks only. No class components.
- Co-locate component, test, and styles in the same directory.
- Named exports over default exports.
- Keep components under 150 lines. Split into container/presentational when larger.
- `"use client"` directive on client components in Next.js projects.

## Data Fetching

- Use `@tanstack/react-query` for server state. No manual `useEffect` + `useState` for fetching.
- API client functions in `src/api/` — one file per domain.
- Type all API responses with shared interfaces in `src/types/`.
- Handle loading, error, and empty states explicitly in every data-fetching component.

## Accessibility Requirements

- Semantic HTML: `button` for actions, `a` for navigation, `nav`/`main`/`section` for layout.
- `aria-label` on icon-only buttons and non-text interactive elements.
- Color contrast: WCAG 2.1 AA (4.5:1 normal text, 3:1 large text).
- Keyboard navigation for all interactive elements.
- Test with axe-core in component tests.

## Performance Budgets

- Initial JS bundle: < 200KB gzipped.
- Per-route chunks: < 50KB gzipped.
- Images: `next/image` or responsive `srcset` with WebP.
- Core Web Vitals: LCP < 2.5s, FID < 100ms, CLS < 0.1.
- Lazy-load below-the-fold content.

## Testing

### Frontend
- Jest + React Testing Library for components.
- Query by role, label, or text — not by test ID or CSS class.
- Test user-visible behavior, not implementation details.

### BFF Lambda
- pytest + moto for BFF handler tests.
- `mock_aws` context manager for AWS service mocking.
- `make_api_event()` helper for API Gateway proxy events.

### E2E
- Playwright for critical user journeys.
- Accessible selectors: `getByRole`, `getByLabel`, `getByText`.
- Mock API responses with `page.route()` for deterministic tests.

## BFF Lambda Pitfalls

- HTTP API v2 has a 30-second timeout. Keep BFF calls fast.
- Never reference `ServerlessHttpApi` in Lambda env vars.
- `sam build` needs Python version matching the runtime.
<!-- claude-hub:fragment:end — Add your project-specific content below this line. -->

# Project Notes

<!-- Add project-specific guidance: component library, design system, API contracts, routing conventions. -->

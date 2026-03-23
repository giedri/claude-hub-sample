# Frontend Team - Team CLAUDE.md

## Team Overview

- **Team name**: Frontend
- **Domain**: Web applications, user-facing interfaces, and API integration
- **Slack channel**: #team-frontend
- **On-call rotation**: https://pagerduty.internal.acme.com/frontend
- **Team lead**: TBD

## Tech Stack

- **Languages**: TypeScript 5.x, Python 3.12+ (for BFF Lambda functions)
- **Frameworks**: React 18+, Next.js 14+, Tailwind CSS
- **Infrastructure**: AWS SAM (API Gateway + Lambda for BFF), S3 + CloudFront for static hosting
- **Databases**: DynamoDB (session/state), S3 (assets)
- **CI/CD**: GitHub Actions with shared workflows
- **Testing**: Jest, React Testing Library, Playwright (E2E), pytest (BFF Lambdas)
- **Bundler**: Vite

## Team Conventions

### Code Style

- Use ESLint with `@typescript-eslint/recommended` and Prettier for TypeScript/React code.
- Use Black (line length 100) for any Python BFF Lambda code.
- Prefer named exports over default exports.
- Co-locate component files: `ComponentName/index.tsx`, `ComponentName.test.tsx`, `ComponentName.module.css`.
- Use `interface` for object shapes, `type` for unions and intersections.

### Component Patterns

- Use functional components with hooks exclusively. No class components.
- Extract reusable logic into custom hooks (`use*.ts`).
- Keep components under 150 lines. Split into container (data-fetching) and presentational (rendering) components when they grow.
- Use React Server Components in Next.js where possible. Client components must have `"use client"` directive.
- Handle loading, error, and empty states explicitly in every data-fetching component.

### API Integration

- Use `@tanstack/react-query` for server state management. No manual `useEffect` + `useState` for data fetching.
- Define API client functions in `src/api/` — one file per domain (e.g., `products.ts`, `users.ts`).
- Type all API responses with shared TypeScript interfaces in `src/types/`.
- BFF Lambda endpoints follow the same Python handler patterns as the org standard.

### Branching Strategy

- Short-lived feature branches off `main`.
- Branch naming: `{type}/{ticket-id}-{short-description}` (e.g., `feat/FE-123-add-cart-drawer`).
- Squash merge to main.

### Testing Standards

- Unit tests for all utility functions and custom hooks.
- Component tests with React Testing Library for user-facing behavior (not implementation details).
- E2E tests with Playwright for critical user journeys (checkout, auth, navigation).
- BFF Lambda functions tested with pytest and moto, following org testing standards.
- Minimum 80% code coverage for new code.

### Accessibility

- All interactive elements must be keyboard-navigable.
- Use semantic HTML elements (`button`, `nav`, `main`, `section`) over generic `div`.
- Include `aria-label` on icon-only buttons and non-text interactive elements.
- Color contrast must meet WCAG 2.1 AA (4.5:1 for normal text, 3:1 for large text).
- Test with axe-core in component tests.

### Performance

- Bundle size budgets: initial JS < 200KB gzipped, per-route chunks < 50KB gzipped.
- Images must use `next/image` or responsive `srcset` with WebP format.
- Lazy-load below-the-fold content and non-critical components.
- Core Web Vitals targets: LCP < 2.5s, FID < 100ms, CLS < 0.1.

### Deployment

- Deploy to staging automatically on merge to main.
- Production deploys require manual approval in GitHub Actions.
- Static assets deployed to S3 + CloudFront with cache-busting hashes.
- BFF Lambdas deployed via SAM alongside the static deployment.

## Overrides

### Testing Framework

- **Org standard**: pytest for all tests.
- **Team override**: Jest + React Testing Library for frontend code, Playwright for E2E. pytest is used only for BFF Lambda functions.
- **Reason**: React ecosystem tooling (Jest, RTL) provides better component testing ergonomics and is the industry standard for React applications.

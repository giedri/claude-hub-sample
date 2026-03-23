# Component Review

Reviews React components against frontend team standards for structure, accessibility, performance, and testing.

## Steps

1. **Identify changed components**
   ```bash
   git diff --name-only main...HEAD -- 'src/**/*.tsx' 'src/**/*.ts'
   ```

2. **Component structure**
   - Functional components with hooks only. Flag any class components.
   - Components should be under 150 lines. Flag oversized components and suggest splitting into container/presentational.
   - Co-location: component, test, and styles should be in the same directory.
   - Named exports preferred over default exports.
   - `"use client"` directive present on client components in Next.js projects.

3. **State and data fetching**
   - Server state must use `@tanstack/react-query`. Flag manual `useEffect` + `useState` patterns for data fetching.
   - Reusable logic must be in custom hooks (`use*.ts`), not duplicated across components.
   - Loading, error, and empty states must be handled explicitly in data-fetching components.

4. **Accessibility**
   - Interactive elements must be keyboard-navigable (no click handlers on `div` or `span` without `role` and `tabIndex`).
   - Semantic HTML: `button` for actions, `a` for navigation, `nav`/`main`/`section` for layout.
   - `aria-label` on icon-only buttons and non-text interactive elements.
   - Images must have meaningful `alt` text (or `alt=""` for decorative images).
   - Form inputs must have associated `label` elements.

5. **Performance**
   - Images use `next/image` or responsive `srcset` with WebP.
   - Below-the-fold content and heavy components use lazy loading (`React.lazy` or dynamic imports).
   - No inline object/array creation in JSX props (causes unnecessary re-renders).
   - Memoization (`useMemo`, `useCallback`) used appropriately for expensive computations or stable references passed to child components.

6. **TypeScript**
   - Props defined with `interface`, not `type` (unless union/intersection is needed).
   - No `any` types. Use `unknown` and narrow with type guards.
   - API response types defined in `src/types/` and shared across components.

7. **Testing**
   - Component tests exist using React Testing Library.
   - Tests query by role, label, or text -- not by test ID or CSS class.
   - Tests verify user-visible behavior, not implementation details (no testing internal state).
   - Accessibility checked with `axe-core` assertions where applicable.

## Output

Provide a summary organized by category:
- **Structure**: Component size, organization, or pattern violations.
- **Accessibility**: Missing ARIA attributes, semantic HTML issues, keyboard navigation gaps.
- **Performance**: Bundle size concerns, missing lazy loading, unnecessary re-renders.
- **TypeScript**: Type safety issues.
- **Testing**: Missing or inadequate component tests.

For each finding, include the file path, line number, the issue, and the recommended fix.

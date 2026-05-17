# Performance Strategies — eng-web-build

## Core Web Vitals targets

| Metric | Good | Needs improvement | Poor |
|--------|------|-------------------|------|
| LCP (Largest Contentful Paint) | ≤ 2.5s | 2.5s–4.0s | > 4.0s |
| INP (Interaction to Next Paint) | ≤ 200ms | 200ms–500ms | > 500ms |
| CLS (Cumulative Layout Shift) | ≤ 0.1 | 0.1–0.25 | > 0.25 |

Flag any step that introduces a new above-the-fold resource, large bundle, or layout-affecting element — note which CWV is at risk and what the mitigation is.

---

## Code splitting

- **Route-level**: Next.js splits by page automatically. No action needed for page-level components.
- **Component-level**: Use `next/dynamic` for heavy components not needed on initial render.
  ```tsx
  const HeavyChart = dynamic(() => import('./HeavyChart'), { ssr: false });
  ```
- **Library-level**: Import only what is used. Avoid barrel imports from large libraries (`lodash`, `date-fns`, etc.) — use path imports instead.
  ```ts
  // Bad
  import { format } from 'date-fns';
  // Good
  import format from 'date-fns/format';
  ```
- **Verify split**: after adding dynamic imports, confirm the chunk appears separately in the Next.js build output (`next build`).

---

## Lazy loading

- **Images below the fold**: always `loading="lazy"` (Next.js `<Image>` defaults to this for non-priority images).
- **Above-the-fold images**: set `priority` on the LCP image to preload it. Only one `priority` image per page.
- **Components**: use `React.lazy` + `<Suspense>` for components not in the critical rendering path.
  ```tsx
  const Modal = React.lazy(() => import('./Modal'));
  // wrap with <Suspense fallback={<Spinner />}>
  ```
- **Intersection Observer**: use for deferring data fetches or animations until the element scrolls into view. Prefer the `useInView` hook from `react-intersection-observer` over manual observer setup.

---

## Caching strategies

| Layer | Tool | When to use |
|-------|------|-------------|
| HTTP / CDN | `Cache-Control` headers | Static assets, API responses that rarely change |
| Client data | `SWR` or `React Query` | Server data fetched in components — stale-while-revalidate by default |
| Next.js fetch cache | `fetch` with `next: { revalidate }` | Server components, ISR pages |
| Memoisation | `useMemo` / `useCallback` / `React.memo` | Expensive calculations or stable callback references passed to children |

Rules:
- Do not add `useMemo` / `useCallback` speculatively. Add them only when a measured render bottleneck exists or when stabilising a reference that would otherwise break a dependency array.
- Set `Cache-Control: no-store` for routes that return personalised or user-specific data.
- Use ISR (`revalidate`) instead of SSR for pages whose data changes infrequently (product listings, blog posts, etc.).

---

## Image optimisation

- **Always use `next/image`** for any `<img>` in the app. Never write a raw `<img>` tag.
- **Dimensions**: provide explicit `width` and `height` (or use `fill` with a positioned container) to prevent CLS.
- **Format**: Next.js serves WebP/AVIF automatically when the browser supports it. No manual format conversion needed.
- **Sizing**: set `sizes` prop to match the rendered size at each breakpoint.
  ```tsx
  <Image src={src} alt={alt} sizes="(max-width: 768px) 100vw, 50vw" fill />
  ```
- **Remote images**: add the domain to `next.config.js` `images.remotePatterns` — do not use the deprecated `domains` key.
- **Placeholder**: use `placeholder="blur"` with a `blurDataURL` for above-the-fold images to reduce perceived load time.

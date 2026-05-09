---
name: Scope Matrix
description: Maps PRD feature types to engineering domains (determines which agents activate)
type: reference
---

# Scope Matrix

Use this matrix during RFC drafting to assign each PRD feature to one or more engineering domains. Every PRD §5 row must map to at least one domain. A row that maps to multiple domains is a coordination point — the RFC must name a lead agent.

## Engineering domains

| Domain code | Agent name | Owns |
|-------------|-----------|------|
| `ios` | mobile-eng-ios | iOS app — Swift, SwiftUI/UIKit, Apple-specific APIs (HealthKit, Push, StoreKit) |
| `android` | mobile-eng-android | Android app — Kotlin, Jetpack Compose, Google-specific APIs (FCM, Play Billing) |
| `web` | web-eng | Web frontend — TypeScript, framework du jour, browser APIs |
| `backend` | backend-eng | Server-side services, REST/GraphQL APIs, business logic |
| `db` | backend-eng (or `data-eng` if dedicated) | Schema migrations, query optimization, replication |
| `infra` | infra-eng | CI/CD, deploy pipelines, observability, IaC |
| `data` | data-eng | Analytics events, ETL, dashboards, data warehousing |
| `design` | design (human, not agent) | UX, visual design, design system tokens |
| `qa` | qa-eng | Test plans, integration test authoring, manual QA passes |

## Feature-type → domain map

Use the row whose feature description best matches the PRD §5 feature. When in doubt, map to all plausible domains and let `plan-em` ask one clarifying question.

| Feature pattern | Required domains | Lead agent | Notes |
|-----------------|-----------------|-----------|-------|
| User-facing screen on mobile | `ios`, `android`, sometimes `backend` | platform with most logic | Backend only if new endpoint required. |
| User-facing screen on web | `web`, sometimes `backend` | `web` | Backend only if new endpoint required. |
| Push notification | `backend`, `ios`, `android` | `backend` | Backend owns scheduling, clients own permission and rendering. |
| New persisted entity | `db`, `backend`, all clients reading it | `backend` | Schema migration is a separate phase before client work. |
| New API endpoint | `backend`, all clients calling it | `backend` | OpenAPI spec must merge before client work begins. |
| Authentication change | `backend`, `ios`, `android`, `web` | `backend` | All clients must coordinate — never ship one platform alone. |
| Analytics event | `data`, all platforms emitting it | `data` | Event schema in `data` domain; clients emit. |
| Background job | `backend`, `infra` | `backend` | Infra owns scheduler config; backend owns job logic. |
| In-app purchase | `ios` (StoreKit), `android` (Play Billing), `backend` (receipt validation) | `backend` | Three-way coordination; receipts validated server-side. |
| Deep link | `ios`, `android`, sometimes `web` | platform with most flow logic | Web only if a public-facing URL exists. |
| Read-only dashboard | `web`, `backend` (read replica) | `web` | Often a P1 phase that ships after mobile. |
| Migration of existing user data | `db`, `backend`, `data` (verification) | `backend` | Always include a rollback plan in the RFC. |

## Decision rules

Apply in order:

1. **Does the feature persist data?** If yes, `db` and `backend` are required.
2. **Does the feature have a UI?** If yes, list every platform with the UI in scope per PRD §4.
3. **Does the feature cross a network boundary?** If yes, `backend` is required as the contract owner, and the OpenAPI / GraphQL schema is a Phase 1 deliverable.
4. **Does the feature emit analytics?** If yes, add `data` and confirm event schema before client work.
5. **Does the feature require infra change** (new queue, scheduler, secret, hostname)? If yes, add `infra`.
6. **If only one domain is involved**, no lead agent is needed — the single domain owns the work.

## Worked example

**PRD-1 §5 F2:** "Track streak. Increment streak when user logs habit before midnight local time. Streak +1 when log occurs in [00:00, 23:59] local; resets to 0 if 24h elapses without a log."

Apply decision rules:

1. Persists data → `db`, `backend`.
2. UI → iOS and Android display the streak count.
3. Network boundary → yes, mobile reads from `/streaks/{user_id}`.
4. Analytics → emit `streak_incremented` event → add `data`.
5. Infra → no.

**Mapping:**

| Domain | Role |
|--------|------|
| `backend` | Lead. Owns streak logic, timezone handling, endpoint, schema migration. |
| `db` | Schema migration for `streaks` table. |
| `ios` | Renders streak count, calls endpoint. |
| `android` | Renders streak count, calls endpoint. |
| `data` | Owns `streak_incremented` event schema. |

**Lead agent:** `backend-eng`. Phase 1 must merge OpenAPI spec and schema migration before mobile work begins.

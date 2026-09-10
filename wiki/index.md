# CircleLink Knowledge Index

This is the content-oriented entry point for CircleLink's maintained knowledge. Read the relevant
living pages first, then follow their decision and source links.

## Product

- [Chat](product/chat.md) — Direct and group conversations, list behavior, realtime delivery, and push boundaries.
- [Communities](product/communities.md) — Discovery, membership, posts, media, and group chat.
- [Connect](product/connect.md) — Candidate discovery, gestures, matches, and first-use guidance.
- [Product overview](product/overview.md) — Stable scope and entry points for the CircleLink product.
- [Profile and account](product/profile-and-account.md) — Public profiles, private age data, posts, and account lifecycle.

## Architecture and Backend

- [Architecture overview](architecture/overview.md) — Layers, dependency direction, state, navigation, and core rules.
- [Firebase backend](backend/firebase.md) — Authentication, Firestore, FCM, Functions, rules, and local validation.
- [Supabase media storage](backend/supabase-media.md) — Public media storage boundaries and configuration.
- [Unified post likes](backend/post-likes.md) — Like transactions, activity, notifications, migration, and constraints.

## Design and Engineering

- [Sunset Parchment design system](design/design-system.md) — Canonical visual tokens, components, motion, and accessibility.
- [UI component organization](engineering/ui-components.md) — Boundaries between shared and feature-owned components.

## Process and Quality

- [Development workflow](process/development-workflow.md) — Branch promotion, GitHub tracking, and wiki gates.
- [Local development and setup](operations/local-development.md) — Provider configuration and validation commands.
- [Testing and validation](quality/testing.md) — Automated and manual verification boundaries.

## Decisions

### Architecture and backend

- [Firebase and Supabase responsibilities](decisions/backend/firebase-and-supabase-responsibilities.md) — Provider ownership for identity, data, push, and media.
- [Repository-driven MVVM](decisions/architecture/repository-driven-mvvm.md) — Presentation, domain, data, and dependency-injection boundaries.
- [Unified post-like model](decisions/backend/unified-post-like-model.md) — Deterministic membership, atomic counts, and activity delivery.

### Chat and Connect

- [Connect hybrid onboarding](decisions/connect/hybrid-onboarding.md) — Demonstration and safe practice for both swipe directions.
- [Contextual guide system](decisions/connect/contextual-guide-system.md) — Readiness, placement, persistence, and feature handoff.
- [Firestore chat realtime source](decisions/chat/firestore-realtime-source.md) — Firestore as the only message source of truth.
- [Profile image rendering](decisions/connect/profile-image-rendering.md) — Aspect-fit profile images inside stable containers.

### Design and profile

- [Adopt Sunset Parchment](decisions/design/adopt-sunset-parchment.md) — CircleLink's canonical visual language.
- [Keep full birth date private](decisions/profile/private-birth-date.md) — Private canonical date and public derived age.
- [Reusable UI component boundaries](decisions/design/reusable-ui-components.md) — Shared primitives and feature-local specialization.
- [Reversible account deactivation](decisions/profile/reversible-account-deactivation.md) — Soft deactivation, recovery, and cleanup boundary.

### Process

- [Branching and release flow](decisions/process/branching-and-release-flow.md) — Integration, stabilization, production, and tracking stages.
- [Repository-local LLM Wiki](decisions/process/repository-local-llm-wiki.md) — Knowledge layers, governance, and automatic maintenance.

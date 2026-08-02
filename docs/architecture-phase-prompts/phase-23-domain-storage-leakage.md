# Phase 23 — Domain storage leakage cleanup (option A only)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Make Domain/Data boundaries clearer around storage-shaped fields **without** changing Firestore schema or wire format.

**Approved approach: A only** — documentation + mapping/DTO clarity. No Domain media redesign (B). No moving `OrganizedChats` sectioning (C) in this phase.

## Why

- `User.avatarBase64` exposes a Spark-plan storage workaround on the core entity.
- Comments/mappers blur “Domain model” vs “Firestore document shape”.

We improve readability and layering without a migration.

## Context

- `Domain/Models/User.swift` (`avatarBase64`)
- Firestore user mapper / `FirestoreUserRepository`
- Profile save/load path that reads/writes this field
- `ARCHITECTURE.md` (optional one-line note)

## Scope (A only)

1. Introduce a **Data-layer** DTO or mapper-focused type for the Firestore user document fields that are storage-specific (at least avatar base64), if it clarifies mapping.
2. Keep `User` compiling for the rest of the app — you may keep `avatarBase64` on `User` for now if removing it forces a wide churn; if so, document that Domain still carries a persistence leftover and what a future B phase would do.
3. Prefer: mapper owns encode/decode comments + naming that says “storage field”; avoid leaking Spark comments deeper into Features.
4. No schema change: same keys/values in Firestore.
5. Update tests/mappers if they assert document shape.

## Out of scope

- Removing `avatarBase64` from Domain entirely (needs explicit future phase)
- Changing how images are stored (Supabase vs base64)
- `OrganizedChats` presentation move
- UI avatar picker redesign
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-23-domain-storage-leakage-a`.
2. Trace read/write of avatar base64.
3. Minimal DTO/mapper clarity → build → profile-related tests if any.

## Acceptance criteria

- [ ] Storage mapping clearer in Data (DTO and/or mapper docs)
- [ ] Firestore wire format unchanged
- [ ] Profile load/save still works
- [ ] Build passes

---
id: adr-backend-firebase-and-supabase-responsibilities
title: Firebase and Supabase Responsibilities
type: decision
status: implemented
date: 2026-07-28
tags: [backend, firebase, supabase, media]
sources:
  - legacy:CircleLink/App/FIREBASE_SETUP.md
  - legacy:CircleLink/App/SUPABASE_SETUP.md
---

# Firebase and Supabase Responsibilities

## Context

CircleLink needs identity, structured realtime data, push integration, and image storage while
keeping provider boundaries explicit.

## Decision

Firebase owns authentication, Firestore documents, rules, indexes, and FCM integration. Supabase
Storage owns chat attachments, profile-post images, community covers, and community-post images.
Firestore stores public URLs for those binaries. Small compressed profile avatars remain base64 in
the user document.

The current Supabase bucket is public and its anonymous mutation policy is an MVP constraint, not
a private-media guarantee.

## Consequences

Domain and UI code access both providers through injected protocols. Media access is simple but
URL possession grants reads; privacy hardening requires a coordinated server policy and client
change.

## Sources

- [Firebase backend](../../backend/firebase.md)
- [Supabase media](../../backend/supabase-media.md)
- `CircleLink/Data/Firebase/` and `CircleLink/Data/Supabase/`.

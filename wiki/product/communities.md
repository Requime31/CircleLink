---
title: Communities
type: product
status: current
updated: 2026-09-11
tags: [product, communities]
---

# Communities

Signed-in users can discover and search communities, create a community, join or leave, view
members, publish text or image posts, and enter the community group chat. The creator is recorded
as the community owner and initial admin. Membership and `memberCount` change atomically.

Community metadata and posts live in Firestore. Cover and post image binaries live in Supabase
Storage, while Firestore stores their public URLs. Community post likes share the unified post
activity model with profile posts.

## Sources

- `CircleLink/Features/Communities/`.
- `CircleLink/Data/Firebase/FirestoreCommunityRepository.swift`.
- `CircleLink/Data/Firebase/FirestoreCommunityPostRepository.swift`.
- [Firebase backend](../backend/firebase.md).
- [Supabase media](../backend/supabase-media.md).

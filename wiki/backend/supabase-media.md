---
title: Supabase Media Storage
type: backend
status: current
updated: 2026-09-11
tags: [backend, supabase, media, security]
---

# Supabase Media Storage

Supabase Storage holds chat attachments, profile-post images, community covers, and community-post
images. Firebase remains responsible for authentication and database data. Firestore documents
store public image URLs rather than image binaries.

Create a public bucket named `chat-images`. Expected object prefixes are `chats`, `profilePosts`,
`communities`, and `communityPosts`. Current public URLs allow anyone possessing a URL to fetch the
object. Private delivery requires coordinated storage policies, authentication, and client work.

Copy `CircleLink/SupabaseSecrets.plist.example` to `CircleLink/SupabaseSecrets.plist`, then provide
the project URL and anonymous public key locally. Never commit the real file. Without this config,
text and Firestore-backed features work, while media uploads return a configuration error.

Current anonymous upload and delete policies are an MVP constraint and should be hardened before
production. Deletion of profile and community media is best effort; chat attachments are retained.

## Sources

- Legacy `CircleLink/App/SUPABASE_SETUP.md`, migrated during bootstrap.
- `CircleLink/Data/Supabase/`.
- `CircleLink/SupabaseSecrets.plist.example`.
- [Firebase and Supabase responsibilities](../decisions/backend/firebase-and-supabase-responsibilities.md).

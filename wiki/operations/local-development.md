---
title: Local Development and Setup
type: operations
status: current
updated: 2026-09-11
tags: [operations, xcode, firebase, supabase]
---

# Local Development and Setup

## Requirements

- macOS and a recent Xcode.
- Apple signing for device builds.
- Firebase project for authentication, Firestore, and FCM.
- Supabase project for media uploads.
- Node.js 22 and Firebase CLI for backend tests and functions work.

Open `CircleLink.xcodeproj`, select the CircleLink scheme, and run on an iOS simulator. The minimum
supported system is iOS 16.

## Local configuration

```bash
cp CircleLink/GoogleService-Info.plist.example CircleLink/GoogleService-Info.plist
cp CircleLink/SupabaseSecrets.plist.example CircleLink/SupabaseSecrets.plist
```

Fill both local files from their provider dashboards. They are ignored and must never be committed.
Resolve Swift packages through Xcode if required.

## Validation commands

```bash
xcodebuild -project CircleLink.xcodeproj -scheme CircleLink \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build

node wiki/tools/lint-wiki.js

firebase emulators:exec --only firestore --project demo-circlelink-likes \
  'npm --prefix functions test'
```

Choose focused iOS tests based on the changed feature. Real APNs delivery, spoken VoiceOver output,
and device-only behavior require manual device validation.

## Provider setup

- [Firebase backend](../backend/firebase.md)
- [Supabase media storage](../backend/supabase-media.md)

## Sources

- Legacy `README.md` and provider setup documents.
- `CircleLink.xcodeproj/project.pbxproj`.
- `functions/package.json`.

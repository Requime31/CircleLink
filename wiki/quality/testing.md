---
title: Testing and Validation
type: quality
status: current
updated: 2026-09-11
tags: [quality, testing, swift-testing, firebase]
---

# Testing and Validation

CircleLink uses Swift Testing for domain, mapper, repository, ViewModel, state, navigation, and
component behavior. XCTest hosting tests render layout-sensitive SwiftUI states when visual bounds
matter. Mocks keep unit tests independent from Firebase.

Firestore rules, transactions, activity functions, and migrations use the Firestore Emulator and
Node's built-in test runner. Provider deployment, production migration, APNs/FCM delivery, real
VoiceOver speech, and device-only interaction require explicit manual validation.

Tests should target meaningful behavior and regressions. Reversible mechanical changes do not
need tests that merely mirror implementation. Build and focused checks run before broader suites;
broader testing is justified by shared infrastructure or unresolved risk.

Wiki maintenance has two checks: deterministic JavaScript lint for structure and links, plus
semantic agent review for contradictions and unsupported claims after significant ingestion or
before stabilization and release promotion.

## Sources

- `CircleLinkTests/`.
- `functions/test/likes.test.js`.
- `wiki/tools/lint-wiki.js`.
- Existing validation records in migrated documentation and Git history.

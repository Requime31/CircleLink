---
name: test
description: Run CircleLink ViewModel unit tests (CircleLinkTests). Use when the user asks to run tests, verify tests, or check the test target.
---

# Run tests

ViewModel tests live in `CircleLinkTests/`. They use Swift Testing and **mock repository protocols** — Firebase is not required.

Scheme: **CircleLink**. Test target: **CircleLinkTests**.

## Xcode

1. Open `CircleLink.xcodeproj` (the project, not a random folder).
2. Scheme **CircleLink**, any iOS Simulator.
3. **Product → Test** (⌘U).

## CLI (macOS + Xcode)

```bash
xcodebuild test \
  -scheme CircleLink \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:CircleLinkTests
```

If that simulator name is missing, list devices with `xcrun simctl list devices available` and pick an iOS Simulator.

## What “pass” means

- Tests mock `AuthRepository`, `ChatRepository`, and the other Domain protocols.
- Do not hit live Firestore or Supabase in unit tests.
- After a ViewModel behavior change, update or add tests in `CircleLinkTests/` — do not skip because “it compiles”.

## Do not

- deploy Firebase rules as part of running tests
- add XCTest-only style unless the file already uses it; this target is Swift Testing

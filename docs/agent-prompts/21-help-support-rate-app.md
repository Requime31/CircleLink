# PR 21 — Help, Support and Rate App

## Objective

Создай `codex/help-support-rate-app`. Реализуй локальный FAQ, Support email flow с fallback и Rate App через StoreKit, подключив Settings PR 19. Не commit/push.

## Context

Сохрани dirty changes. Прочитай AI docs, architecture/design, Settings routes, app bundle metadata and deployment target. Не добавляй analytics, web backend или dependency.

## Requirements

FAQ — local structured data и native searchable/expandable screen (если search оправдан объёмом), вопросы по account, age, Connect/likes/matches, communities, chats/mute/hide/pin, block/report, notifications/reminders, privacy/delete. Ответы не обещают неподтверждённое backend behavior и могут ссылаться на Legal/Support.

Support: protocol/presenter around `MFMailComposeViewController` либо корректный SwiftUI wrapper. Recipient вынеси в non-secret app configuration с явным placeholder, subject включает CircleLink Support, body prefill version/build/iOS/device model без user ID, message/chat content или другой PII. Если mail unavailable, предложи копировать адрес/open `mailto:` safely; Cancel не ошибка.

Rate App: user-tap вызывает scene-aware `SKStoreReviewController.requestReview(in:)`; не обещай появление prompt и не вызывай автоматически. Если появится App Store ID позже, external review URL вне scope.

## Tests/Done

Tests structured FAQ, support payload excluding PII, capability fallbacks, rate presenter invocation. Build/manual mail available/unavailable, review tap, VoiceOver/Dynamic Type/dark mode, `git diff --check`. Финал: files, configured placeholder, tests and system behaviors not guaranteeable. Не commit/push.

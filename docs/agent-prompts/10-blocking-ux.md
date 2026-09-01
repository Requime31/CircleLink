# PR 10 — Unified blocking UX

## Objective

Создай `codex/unified-blocking-ux`. Улучши уже работающую блокировку: единый confirmation UI в Connect, Peer Profile и direct chat, корректные async states и мгновенное удаление peer из UI. Не переписывай backend. Не commit/push.

## Context and prerequisite

Сохрани dirty changes. Полностью прочитай `docs/ai/AGENTS.md`, `docs/ai/PROJECT.md`, `docs/ai/DECISIONS.md`, `docs/ai/DESIGN_SYSTEM.md`, `ARCHITECTURE.md`, `DESIGN.md`, moderation repository/implementation/rules, Connect/PeerProfile/ChatSheet/ViewModels/tests. Посмотри assets PR 09; если их нет, используй существующие SF Symbol placeholders без генерации новых файлов и отметь prerequisite. Блокировка уже реализована — не создавай второй repository/collection.

## Requirements

Создай переиспользуемый SwiftUI block confirmation presentation: иллюстрация, имя peer, краткие последствия, Cancel и destructive Block. Текст обещает только подтверждённое поведение: peer исчезает из Connect/likes/matches и новые direct interactions блокируются; не обещай удаление истории или взаимную невидимость, если backend этого не гарантирует. Во время запроса disable actions/progress; double taps исключены; ошибка остаётся на экране с retry.

Подключи flow в Connect cards/menus, `PeerProfileSheet` и direct `ChatSheetView`. Group/community chat не должен предлагать блокировку самого community. После success синхронно обнови локальные candidates, incoming, matches и закрывай peer sheet/chat presentation безопасно; затем quiet refresh. Сохрани report отдельно. Все ViewModels `@MainActor`, session/generation/cancellation guards обязательны.

UI: Sunset Parchment, raster asset если доступен, scalable layout, Dynamic Type, VoiceOver, Reduce Motion, dark mode.

## Tests and Done

Покрой success/error/retry/double-tap/session swap и локальное удаление из каждой коллекции. Build/full relevant tests, manual entry points, `git diff --check`. Готово, когда все entry points используют один UX и existing moderation API, ошибки не закрывают sheet, blocked peer исчезает без restart. Финал: files, behavior, tests, asset fallback. Не commit/push.

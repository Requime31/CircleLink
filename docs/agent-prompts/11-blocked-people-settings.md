# PR 11 — Blocked People settings

## Objective

Создай `codex/blocked-people-settings`. Добавь Settings → Blocked People со списком профилей и unblock с optimistic UI/rollback. Не меняй block storage schema. Не commit/push.

## Context

Проверь dirty state; прочитай AI docs, architecture/design, Settings navigation, `ModerationRepository`, `UserRepository`, Firebase implementations, `PeerProfileSheet`, DI, mocks/tests. Требуются существующие `fetchBlockedUserIds`/`unblockUser`. Если Settings foundation PR 19 отсутствует, добавь минимальный destination в текущий Settings без полного redesign.

## Requirements

Создай `@MainActor BlockedPeopleViewModel` с injected moderation/user repositories и explicit `ViewState`. Получай IDs, затем профили bounded/concurrently с cancellation; отсутствующий/деактивированный профиль отображай безопасной fallback row без PII. Не добавляй bulk Firestore reads во View.

Экран имеет loading, empty (asset PR 09 при наличии), error/retry и list. Row: squircle avatar, display name, Unblock. Перед unblock — confirmation; optimistic remove, repository call, rollback на исходную позицию при ошибке. Защити double tap и session swap. После success другие features должны увидеть изменение при обычном refresh; не создавай global event bus без необходимости.

Dynamic Type, VoiceOver actions/labels, 44pt targets, dark mode. Не открывай заблокированный peer profile, если это создаёт interaction path. Не реализуй search/bulk unblock.

## Tests and Done

Tests: empty/load/error/retry, missing profiles, deterministic ordering, successful unblock, rollback, concurrent taps, cancellation. Обнови mocks/DI, build/tests, manual settings navigation, `git diff --check`. Готово, когда список отражает repository truth и failure не теряет row. Финал: files, tests, fallback behavior. Не commit/push.

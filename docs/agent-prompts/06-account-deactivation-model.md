# PR 06 — Account deactivation model

## Objective

Создай `codex/account-deactivation-model`. Реализуй data/domain foundation мягкого удаления на 30 дней и исключение деактивированных пользователей из новых социальных взаимодействий. UI удаления и cleanup worker вне scope. Не commit/push.

## Required context

Сохрани пользовательские изменения. Полностью прочитай AI docs, `ARCHITECTURE.md`, `DESIGN.md`, Firebase setup/rules/indexes; исследуй User/Auth/UserRepository, connection/community/moderation repositories, mappers, coordinator bootstrap, mocks/tests. Не используй Cloud Functions: текущий production path — Spark + Node worker.

## Schema and API

Введи domain enum account state с backward-compatible default active и поля `deletionRequestedAt`, `scheduledDeletionAt`. Firestore names должны быть стабильными и документированными. Добавь `UserRepository.requestAccountDeletion(now:)` и `restoreAccount()`; request атомарно выставляет deactivated и deadline `now + 30 calendar days`, restore очищает deletion fields. Операции идемпотентны и требуют current authenticated user.

Все candidate/incoming/match/profile resolution paths должны отфильтровывать deactivated users до показа. Запрети новые connect requests и создание нового direct chat с deactivated peer; существующие сообщения/посты пока не удаляй. Firestore rules не должны позволять клиенту активировать чужой аккаунт или менять deletion state другого user. Не добавляй client-side Auth deletion.

Обнови mapper, stubs/mocks, documentation и indexes только при реальной необходимости. Сохраняй pure Domain и Repository DI.

## Tests

Покрой legacy active default, mapping, deadline, repeat request/restore, missing auth, filtering candidates/requests/matches, race/session change и attempts against deactivated peer. Запусти targeted/full tests, build и `git diff --check`; rules validation/emulator — если доступен.

## Done

Deactivation state сохраняется и восстанавливается, новые social interactions скрывают/отклоняют deactivated peers, legacy users работают. Финал: schema, API, files, tests, security assumptions. Не commit/push.

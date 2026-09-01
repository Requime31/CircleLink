# PR 08 — Account cleanup worker

## Objective

Создай `codex/account-cleanup-worker`. Расширь существующий `websocket-server` безопасной идемпотентной очисткой аккаунтов, у которых прошёл 30-дневный deadline. Не меняй iOS UI. Не commit/push/deploy.

## Context and prerequisite

Проверь dirty tree. Полностью прочитай `docs/ai/AGENTS.md`, `docs/ai/PROJECT.md`, `docs/ai/DECISIONS.md`, `docs/ai/DESIGN_SYSTEM.md`, `ARCHITECTURE.md`, `DESIGN.md`, Firebase/Supabase setup, `websocket-server/README.md`, весь worker source/package scripts, Firestore rules/schema и PR 06 account fields. Если schema deactivation отсутствует, остановись. Cloud Functions не использовать; сохрани текущий FCM worker и Spark-compatible deployment model.

## Requirements

Вынеси cleanup в тестируемый модуль с dependency injection для clock, Firestore/Auth/storage adapters. Query: deactivated users с `scheduledDeletionAt <= now`, bounded batch/page. Для каждого user повторно проверь state/deadline перед destructive actions. В dry-run ничего не изменяется.

Политика: удалить Firebase Auth account, приватный user profile/token/chatRefs/connections/moderation records и принадлежащие пользователю Supabase profile binaries, где безопасно известен path. Сохраняемые community/profile posts и chat messages не удалять каскадно: удалить персональные snapshot fields либо заменить author identity на стабильный `Deleted User` без email/avatar/birth date; сохранить IDs только если нужны referential integrity. Операция должна переживать partial failure и повторный запуск; логировать structured summary без PII/secrets. Ограничить concurrency, не загружать всю коллекцию в память.

Добавь CLI entry/script `--dry-run` и документированный scheduler contract для текущего host, но не разворачивай cron. Конфигурация только env names; `.env` не читать и секреты не коммитить.

## Tests and verification

Node tests: not-due/active skipped, due cleaned, restore race skipped, pagination, dry-run, partial failure/retry, missing Auth user, idempotency, anonymization. Запусти `npm test`/lint доступные scripts и dry-run с mocks; не подключай production. `git diff --check`.

## Done

Worker можно безопасно запускать повторно, он не логирует PII и не затрагивает active users. Финал: modules, deletion/anonymization matrix, commands, deployment step left to user, risks. Не commit/push/deploy.

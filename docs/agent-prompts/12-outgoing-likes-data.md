# PR 12 — Outgoing likes data

## Objective

Создай `codex/outgoing-likes-data`. Добавь data/domain API для исходящих connection requests только со статусом pending, включая query/index/rules, mocks и ViewModel data state. UI списка вне scope. Не commit/push.

## Context

Проверь worktree; прочитай AI docs, architecture/design, `ConnectionRequest`, statuses, `ConnectionRepository`, Firestore mapper/repository, rules/indexes, ConnectViewModel/tests. Сохрани pair/deduplication semantics и MVVM + Repository.

## API and query

Добавь `fetchOutgoingPendingRequests() async throws -> [ConnectionRequest]` либо равноценный явно именованный contract. Firestore query использует current user as sender и status pending, с deterministic newest-first order; добавь минимальный composite index только если query требует. Никогда не возвращай accepted/declined. Rules разрешают чтение только участнику request и не позволяют клиенту произвольно менять sender/status.

В Connect presentation добавь display item с resolved peer `User` и отдельный `ViewState`; profile resolution выполняется repository/ViewModel, не View. Фильтруй blocked и deactivated IDs, пропускай missing profiles, deduplicate по peer/request согласно текущей pair model. Защити load generation/session cancellation. Не меняй Discover/Incoming/Matches UI и не добавляй cancel-like action.

## Tests

Repository/mocks/ViewModel tests: current user requirement, only outgoing pending, ordering, blocked/deactivated/missing profile filtering, empty/error, stale load/session change. Проверь index JSON и rules syntax/emulator если доступен. Build, tests, `git diff --check`.

## Done

Есть один ясный API и load state для будущего UI, query защищён и не смешивает matches/history. В финале перечисли API/schema/index/rules, files и проверки. Не commit/push.

# PR 17 — Stable chat ordering and mute fix

## Objective

Создай `codex/chat-ordering-mute-fix`. Исправь узкий bug: mute/unmute не должен поднимать чат; ordinary chats сортируются по последнему сообщению, pinned сохраняют manual order. Не commit/push.

## Context

Сохрани dirty changes. Прочитай AI docs, architecture/design, `ChatsViewModel`, FirestoreChatRepository/Mapper, chatRefs merge/write logic, ChatListView и tests. PR 15–16 может быть слит; если pin API отсутствует, исправь только ordinary ordering и не изобретай pinning.

## Requirements

Найди реальную причину: fetch ordering, optimistic array mutation, metadata timestamp/server write либо mapper merge. `setChatMuted` меняет только muted flag; не пишет `lastMessageAt`, не reinserts row и не меняет pin rank. После fetch сортировка централизована и детерминирована: pinned manual order; unpinned `lastMessageAt` descending; nil last; stable ID tie-breaker. Local optimistic mute сохраняет текущий визуальный index. Rollback/refetch возвращает canonical order.

Не меняй UI styling, chat message semantics, hidden behavior или schema кроме удаления ошибочной записи поля, если доказано.

## Tests and Done

Regression tests: mute first/middle/last, unmute, reload, equal/nil dates, pinned unaffected, repository error rollback, incoming new message legitimately reorders ordinary chat. Run Chat tests/build/manual list, `git diff --check`. Финал должен назвать root cause, минимальный fix, files/tests. Не commit/push.

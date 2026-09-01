# PR 16 — Chat pinning UI

## Objective

Создай `codex/chat-pinning-ui`. Поверх PR 15 добавь pinned-секцию, pin/unpin и ручное переупорядочивание. Не меняй schema/repository contracts. Не commit/push.

## Context/prerequisite

Проверь worktree; полностью прочитай `docs/ai/AGENTS.md`, `docs/ai/PROJECT.md`, `docs/ai/DECISIONS.md`, `docs/ai/DESIGN_SYSTEM.md`, `ARCHITECTURE.md`, `DESIGN.md`, затем ChatListView/Row/ChatsViewModel/HiddenChats, routes/tests и Stitch chats reference. Нужны `ChatSummary.isPinned/pinOrder` и repository methods; иначе остановись.

## Requirements

`ChatsViewModel` детерминированно разделяет visible chats: pinned по `pinOrder` (stable tie-breaker), остальные по `lastMessageAt` descending. `ChatListView` показывает compact Pinned section выше обычных; не дублирует rows. Context menu: Pin/Unpin. Скрытые никогда не отображаются pinned.

Ручной порядок редактируется нативным доступным способом (`EditButton`/move внутри pinned section) без перевода всего списка в странный Android-like режим. Optimistic reorder сохраняется repository batch; при ошибке rollback и alert. Защити overlapping reorder/pin operations и stale reload. VoiceOver custom move actions, Dynamic Type, 44pt, dark mode, existing peek/context menu.

Не добавляй drag между pinned/unpinned, pin limit, global sync или redesign row.

## Tests/Done

Tests: split/order/ties, pin/unpin optimistic + rollback, reorder persistence, hidden exclusion, concurrent refresh. Build/tests/manual context menus/Edit/VoiceOver, `git diff --check`. Готово, когда order переживает reload и failures не corrupt state. Финал: files, interaction, tests, accessibility/manual results. Не commit/push.

# PR 15 — Chat pinning data

## Objective

Создай `codex/chat-pinning-data`. Добавь per-user pin metadata и repository API для pin/unpin/manual reorder. UI вне scope. Не commit/push.

## Context

Сохрани dirty worktree. Прочитай полностью AI docs, `ARCHITECTURE.md`, `DESIGN.md`, затем `ChatSummary`, `ChatRepository`, Firestore mapper/repository, `chatRefs` schema/rules, ChatsViewModel, mocks/tests. Chat realtime/messages не менять; metadata персональна пользователю.

## Schema/API

В `users/{userId}/chatRefs/{chatId}` (либо фактическом per-user path) добавь `pinned: Bool` и `pinOrder: Int?`. Расширь `ChatSummary` `isPinned` и optional/order field с backward-compatible default. API: idempotent `setChatPinned(chatId:pinned:)` и atomic/batched `reorderPinnedChats(chatIds:)`. Reorder принимает полный ordered set текущих pinned IDs, rejects duplicates/foreign/hidden chats и сохраняет стабильные возрастающие ranks. Unpin очищает rank. Hidden chat автоматически не считается pinned; при hide metadata pin очищается атомарно.

`fetchOrganizedChats` возвращает metadata без изменения message ordering. Rules позволяют владельцу chatRef менять pin fields, но не чужие refs/participants. Не используй global chat doc и не добавляй listener.

## Tests and verification

Mapper legacy defaults, pin/unpin idempotency, reorder, duplicate/unknown IDs, hidden interaction, partial batch failure, current-user guard. Обнови mocks/schema docs/rules; index только при необходимости. Run Chat tests/full build, rules check/emulator если доступен, `git diff --check`.

## Done

Pin state принадлежит user, переживает reload и не влияет на peers/messages. Финал: API/schema/files/tests/security notes. Не commit/push.

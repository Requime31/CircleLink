# PR 14 — Matches open direct chat

## Objective

Создай `codex/match-direct-chat-fix`. Исправь regression: Open Chat из Matches всегда открывает deterministic direct chat с peer, даже если оба состоят в одном community. Это узкий bug-fix PR. Не commit/push.

## Context

Проверь dirty changes; прочитай полностью AI docs, `ARCHITECTURE.md`, `DESIGN.md`, затем `MatchesView`, `ConnectViewModel.openChat`, `ChatRepository.createDirectChat`, mapper ID helpers, `AppDependencies`, `AppCoordinator.pendingChatRoute`, `ChatThreadRoute` и tests. Исследуй реальный data flow, не предполагай причину по описанию. Сохрани MVVM + Repository.

## Requirements

Используй peer user ID как единственный input для `createDirectChat`. Полученный chat ID передай route без `communityId`; title/peer context должен разрешаться как direct. Удали/исправь место, где shared community context подменяет destination group chat. Не меняй deterministic ID algorithm, create behavior, community chat entry points или accepted-match semantics. Защити duplicate tap/loading/error и существующие session guards.

Добавь regression test: current user и peer имеют одно или несколько общих communities; tapping Open Chat вызывает `createDirectChat(peerId)` один раз и coordinator получает direct route/chatId, не `group_<communityId>`. Также negative/error test: repository error не navigates. Если bug расположен в route factory, тестируй его там и в ViewModel integration.

## Verification and Done

Запусти `ConnectViewModelTests`, chat routing tests и build; вручную Matches → Open Chat и Community → group chat, чтобы второе не сломалось. `git diff --check`. Готово при минимальном diff и доказанном regression test. В финале причина, изменённые файлы, тесты и manual result. Не commit/push.

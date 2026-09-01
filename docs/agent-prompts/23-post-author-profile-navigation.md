# PR 23 — Post author profile navigation

## Objective

Создай `codex/post-author-profile-navigation`. Тап по аватару/имени автора чужого community или profile post открывает существующий `PeerProfileSheet`; собственный автор не открывается как peer. Не commit/push.

## Context

Сохрани dirty changes. Прочитай AI docs, architecture/design, `CommunityPostCard`, profile post rows/list, post models/mappers, `PeerProfileSheet`, AppDependencies factories, auth/current user and navigation tests. Не создавай новую profile UI.

## Requirements

Добавь explicit `onSelectAuthor(userId:)` intent от reusable post row к owning screen; row не создаёт repositories/sheets. Сделай avatar+name одной доступной Button `.plain` с 44pt target, не перехватывая post/image/menu taps. Для чужого valid author ID owner представляет `PeerProfileSheet` через existing factory/mode. Для current user либо открывай существующий owner Profile route, если он доступен без cross-tab hack, либо делай author control non-navigating; выбери минимальный текущий convention и покрой test. Missing/deleted/deactivated author показывает `Deleted User` и не navigates.

Не добавляй chat/connect actions, data fetch duplicate или nested buttons. Сохрани squircle avatars, context menus и owner edit/delete actions.

## Tests/Done

Tests: foreign author opens correct ID once, own author behavior, missing/deleted no-op, post tap/menu unaffected. Build/manual community feed, peer profile posts, current profile posts, VoiceOver, `git diff --check`. Готово, когда navigation единообразна и business dependencies остаются у owner/composition root. Финал: files, chosen own-author behavior, tests. Не commit/push.

# PR 13 — People You Liked UI

## Objective

Создай `codex/outgoing-likes-ui`. Используй data state PR 12 и добавь экран People You Liked в Connect. Не меняй repository query/schema. Не commit/push.

## Context and prerequisite

Сохрани dirty changes. Прочитай полностью `docs/ai/AGENTS.md`, `PROJECT.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `DESIGN.md`, `DESIGN_SYSTEM.md`, затем Connect/Matches/LikedYou/PeerProfile/AppDependencies и Stitch Connect references. Если outgoing pending API/state нет, остановись. iOS 16+, MVVM + Repository, Sunset Parchment.

## Requirements

Добавь discoverable entry в Connect рядом с Liked You/Matches, с badge count только если current design позволяет без визуального шума. Экран показывает исключительно исходящие pending: loading, calm illustrated empty, error/retry и list/cards. Row: squircle avatar, `displayNameWithAge`, shared interests при доступности, status “Waiting for response”, chevron/profile action. Тап открывает существующий `PeerProfileSheet` в подходящем read-only/social mode; не давай повторно Say Hi, accept/decline или direct chat до match.

Refresh on appear/pull-to-refresh должен быть quiet при имеющемся content. Block/report entry использует existing moderation flow; после block row исчезает. Accepted/declined/deactivated/missing peers не показываются. Dynamic Type, VoiceOver, dark mode, small screens. Не добавляй cancel request, pagination или новую profile sheet.

## Tests and Done

ViewModel/navigation tests: four states, badge, peer selection, quiet refresh, block removal. Build/tests/manual matrix, `git diff --check`. Готово, когда экран доступен из Connect, не дублирует Matches и не создаёт prohibited actions. В финале: files, screenshots/manual notes, tests, prerequisite assumptions. Не commit/push.

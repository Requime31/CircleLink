# PR 25 — Community header long description

## Objective

Создай `codex/community-header-description`. Защити Community header от длинного description: компактное сокращение и More sheet с полным текстом. Узкий UI PR. Не commit/push.

## Context

Сохрани dirty changes. Прочитай AI docs, architecture/design, `CommunityDetailView`, artwork/header components, route/ViewModel and tests; открой Stitch `community_detail_feed`. Сохрани current navigation/actions/member counts.

## Requirements

В compact header показывай description максимум 3 строки с tail truncation. Кнопка `More` видима только когда текст реально превышает compact layout — используй layout measurement, а не `characterCount` heuristic; measurement не должен создавать infinite layout loop. Тап открывает native sheet/navigation presentation с community name, selectable/scrollable full description и Close. Пустое/whitespace description не занимает место и не показывает More.

Обрабатывай очень длинные непрерывные tokens/URLs, emoji/graphemes, newlines, RTL и accessibility sizes. При больших Dynamic Type можно разумно дать больше vertical space, но header не должен вытеснять feed полностью. VoiceOver читает compact text один раз и ясно называет More. Dark mode и Sunset tokens.

Не менять description storage/limits, Edit Community, feed pagination или artwork.

## Tests/Done

Если measurement logic вынесена pure — unit tests; минимум add ViewModel/text normalization tests. Build/manual matrix: short/exact/overflow/empty/emoji/unbroken/Dynamic Type/rotation, `git diff --check`. Готово без broken layout и false More для short text. Финал: files, measurement approach, manual/tests. Не commit/push.

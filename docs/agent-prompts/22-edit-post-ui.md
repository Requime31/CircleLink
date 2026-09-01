# PR 22 — Edit post UI

## Objective

Создай `codex/edit-post-ui`. Улучши Edit Post action и edit sheet: компактные controls и ограниченная image preview с replace/remove. Repository contracts и persistence не менять. Не commit/push.

## Context

Проверь dirty worktree. Прочитай полностью `docs/ai/AGENTS.md`, `PROJECT.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `DESIGN.md`, `DESIGN_SYSTEM.md`; исследуй profile/community post cards, compose/edit sheets, repositories/ViewModels, photo picker/compression and tests. Определи оба типа постов и переиспользуй UI только если semantics совпадают.

## Requirements

Edit action не должен быть огромной full-width primary button: используй доступный toolbar/menu/compact secondary control с ясным label и 44pt hit target. Owner-only permission сохраняется.

В edit sheet: текущий text, компактная preview zone фиксированного разумного диапазона высоты (не более примерно трети обычного viewport), `scaledToFill`, clipping/continuous radius; отдельные Replace Photo и Remove Photo actions. New selection replaces preview; remove можно отменить до Save. Без изображения показывай компактный add affordance, не большую пустую панель. Keyboard/small screen должны scroll корректно; Save/Cancel видимы через navigation toolbar. Сохрани existing validation: нельзя сохранить пустые text+image; loading/error/double submit/cancel image load handled. Не добавляй crop editor, несмотря на “crop state”: здесь crop означает визуальный aspect-fill preview, оригинальный upload pipeline остаётся.

Sunset Parchment, Dynamic Type, VoiceOver, dark mode. Не меняй create post, storage paths или mapper.

## Tests and Done

ViewModel tests: unchanged save, text edit, replace, remove, invalid empty, upload/repository error, duplicate save. Build/manual portrait/landscape image, keyboard, small screen, both post types, `git diff --check`. Готово, когда preview не захватывает sheet и actions понятны. Финал: files, behavior, tests/manual matrix. Не commit/push.

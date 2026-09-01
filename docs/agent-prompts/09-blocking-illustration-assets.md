# PR 09 — Blocking illustration assets

## Objective

Создай `codex/blocking-illustration-assets`. Сгенерируй и добавь только raster-иллюстрации для block confirmation, blocked empty state и account deletion warning. Business logic/UI composition не менять. Не commit/push.

## Mandatory process

Проверь worktree. Полностью прочитай `docs/ai/AGENTS.md`, `docs/ai/PROJECT.md`, `docs/ai/DECISIONS.md`, `docs/ai/DESIGN_SYSTEM.md`, `ARCHITECTURE.md`, `DESIGN.md`; осмотри существующий asset catalog и реальные экраны blocking/delete. Обязательно используй доступный skill `imagegen`: прочитай его `SKILL.md` полностью и следуй workflow генерации/визуальной проверки. Если tool недоступен, остановись и сообщи, не создавай самодельные placeholders.

## Art direction

Создай единый набор спокойных editorial illustrations: Sunset Parchment, warm clay/peach/cream, мягкие organic shapes, человеческое и безопасное настроение, без текста, логотипов, purple/neon, тяжёлых теней и пугающих security metaphors. Нужны три distinct assets: `BlockUserIllustration`, `BlockedPeopleEmptyIllustration`, `DeleteAccountIllustration`. Композиция центрированная, с безопасными полями, читается в 160–240 pt. Никаких реальных лиц/брендов.

Экспортируй оптимизированный PNG с прозрачным либо согласованным нейтральным фоном, правильными 1x/2x/3x renditions и разумным размером файлов. Если один вариант одинаково работает в обеих темах — документируй; иначе сделай light/dark appearances в `.imageset`. Не растягивай один bitmap между scale slots.

## Scope and verification

Изменения только в `Assets.xcassets` и кратком asset note при необходимости. Не добавляй Swift Views, strings, repositories. Проверь Contents.json, target membership, отсутствие alpha halos, banding/cropping и визуально открой каждый asset через local image viewer на light/dark backgrounds. Build app, `git diff --check`.

## Done

Три production-ready assets именованы стабильно, оптимизированы и визуально согласованы. В финале покажи previews, пути, dimensions/file sizes, generation brief и проверки. Не commit/push.

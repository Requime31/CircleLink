# PR 19 — Settings foundation

## Objective

Создай `codex/settings-foundation`. Перестрой Settings navigation/sections для Appearance, Notifications, Reminders, Language, Help, Support, Rate, Legal и Account, подключая только уже существующие destinations. Не реализуй сами новые features. Не commit/push.

## Context/prerequisites

Сохрани dirty changes. Полностью прочитай `docs/ai/AGENTS.md`, `docs/ai/PROJECT.md`, `docs/ai/DECISIONS.md`, `docs/ai/DESIGN_SYSTEM.md`, `ARCHITECTURE.md`, `DESIGN.md`, затем Settings files/Stitch settings reference, AppDependencies/navigation и готовые PR 01 Appearance, 05 Legal, 07 Account recovery, 11 Blocked People. Отсутствующий prerequisite представь disabled/placeholder row только там, где план явно требует; не реализуй соседний scope.

## Requirements

Секции: Preferences (Appearance destination, Notifications existing), Reminders (Enable/Time placeholders until PR 20), Language (`English`, disabled/non-tappable with honest “More languages coming later”), Help (FAQ, Support, Rate App destinations/placeholders), Legal (Privacy, Terms), Account (Blocked People, Delete Account), About/version. Используй typed routes/NavigationStack existing style; не хранить closures/business calls в row models, если это усложняет.

Каждая row имеет system symbol, title, optional value/description, correct destructive treatment только Delete. Не делай все icons clay/filled cards. Сохрани notification toggle behavior. Dynamic Type, VoiceOver combined labels/values, dark mode.

## Tests/Done

Tests на SettingsViewModel presentation state/routes where feasible; build/manual every destination/back path, notification regression, `git diff --check`. Готово, когда information architecture полна, отсутствующие actions честно disabled, Settings не содержит feature business logic. Финал: files, route map, prerequisites present/missing, tests. Не commit/push.

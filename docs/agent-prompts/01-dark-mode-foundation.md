# PR 01 — Dark mode foundation

## Role and objective

Ты senior iOS engineer. Создай ветку `codex/dark-mode-foundation` и подготовь один reviewable PR: семантическую основу тем `system/light/dark`, без массовой переделки экранов. Не коммить и не пушь без отдельной команды пользователя.

## Repository context and required reading

Перед изменениями проверь `git status` и сохрани чужие незакоммиченные правки. Полностью прочитай `docs/ai/AGENTS.md`, `docs/ai/PROJECT.md`, `docs/ai/DECISIONS.md`, `ARCHITECTURE.md`, `DESIGN.md`, `docs/ai/DESIGN_SYSTEM.md`, затем исследуй `CircleLink/Shared/Design/CLTheme.swift`, `CircleLink/App/CircleLinkApp.swift`, `CircleLink/App/AppCoordinator.swift` и текущие настройки. Проект: iOS 16+, SwiftUI + изолированный UIKit-чат, MVVM + Repository, manual DI; UseCase-слой и новые зависимости запрещены.

## Current state and requirements

Сейчас `CLColor` содержит фиксированные light-only цвета Sunset Parchment. Введи `AppAppearance: String, CaseIterable, Codable` (`system`, `light`, `dark`) и небольшой main-actor store на `UserDefaults`. Применяй выбранную тему через `preferredColorScheme`: `nil`, `.light`, `.dark`. Store должен быть единственным источником истины и инжектироваться/создаваться в composition root.

Сделай все `CLColor` семантическими dynamic colors с явными light/dark вариантами: surfaces, ink, hairlines, primary, soft tints и semantic states. Сохрани публичные имена токенов, чтобы не ломать call sites. Dark palette должна оставаться тёплой Sunset Parchment, не превращаться в pure black или purple; проверь WCAG-практичный контраст текста и destructive/success states. UIKit bridge допустим только в design layer.

Не проводи аудит экранов и не меняй их layout. Не добавляй Settings UI — только модель/store и app-level применение. Не меняй Domain/Firestore.

## Tests and verification

Добавь unit tests для persistence/default/fallback неизвестного значения и mapping appearance → color scheme. Собери:

```sh
xcodebuild -project CircleLink.xcodeproj -scheme CircleLink -destination 'generic/platform=iOS Simulator' build
```

Вручную проверь live switching и повторный запуск для всех трёх режимов. Выполни `git diff --check`.

## Self-review and Definition of Done

Проверь отсутствие Firebase/UserDefaults во Views, iOS 16 compatibility, main-actor state, отсутствие hard-coded screen colors в новых API и сохранение light appearance. Готово, когда тема хранится, применяется без restart, токены динамические, тесты и build проходят, а изменения ограничены foundation.

В финале перечисли изменённые файлы, архитектурные решения, запущенные проверки и оставшиеся визуальные риски. Не заявляй об успешных тестах, которые не запускались.

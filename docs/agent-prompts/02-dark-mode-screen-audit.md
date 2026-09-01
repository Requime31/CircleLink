# PR 02 — Dark mode screen audit

## Role and objective

Ты senior iOS UI engineer. Создай ветку `codex/dark-mode-screen-audit`. Адаптируй весь SwiftUI UI и UIKit chat к уже существующей foundation тем `system/light/dark`. Не реализуй foundation заново. Не commit/push без команды.

## Required context

Сначала `git status`; не перезаписывай чужие изменения. Прочитай полностью `docs/ai/AGENTS.md`, `PROJECT.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `DESIGN.md`, `DESIGN_SYSTEM.md`, а также существующие theme/appearance types. Просмотри все файлы `CircleLink/Features`, `CircleLink/Chat`, shared design components и релевантные Stitch `screen.png`. Архитектура остаётся MVVM + Repository, iOS 16+.

## Prerequisite

PR 01 должен предоставлять semantic dynamic `CLColor`, appearance store и app-level `preferredColorScheme`. Если этого нет, остановись и сообщи prerequisite; не расширяй scope.

## Implementation requirements

Найди hard-coded `Color`, `UIColor`, `.white`, `.black`, RGB/hex, custom toolbar/list backgrounds и замени только UI-цвета на семантические tokens. Не заменяй системный black Apple Sign In и не тонируй пользовательские фотографии. Адаптируй `ChatAppearance`, bubbles, input bar, message states, table background, navigation/tab bars, sheets, alerts, lists, search, placeholders, empty/error/loading states. Сохрани canonical rules: squircle avatars; Connect action buttons circular; clay используется редко; `screenHorizontal = 20`.

Используй `UIColor` dynamic providers либо bridge из общей палитры для UIKit; trait changes должны обновлять уже показанный чат без пересоздания данных. Не меняй layout, тексты, navigation, repositories или product behavior. Исправляй только реальные theme regressions.

## Verification

Собери app и запусти релевантные unit tests. Проведи ручную матрицу System/Light/Dark для Auth, Age Gate, tabs, Connect, Communities, Chats/Hidden/Info/thread, Profile, Settings и всех sheets. Проверь Increased Contrast, Reduce Transparency и screenshots с длинным текстом. Выполни `rg` по hard-coded colors и классифицируй оставшиеся допустимые исключения в финале; `git diff --check` обязателен.

## Definition of Done

Нет нечитаемых labels, светлых вспышек canvas, неправильных UIKit bubbles или невидимых borders в dark mode; light mode визуально не деградировал; scope не содержит редизайна. В финале дай файлы, проверки, осознанно оставленные fixed colors и непроверенные устройства. Не commit/push.

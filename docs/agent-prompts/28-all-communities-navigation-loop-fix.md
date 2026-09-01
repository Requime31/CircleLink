# PR 28 — All Communities navigation loop fix

## Role and objective

Ты senior SwiftUI navigation engineer. Создай ветку `codex/all-communities-navigation-loop-fix`. Исправь navigation stack: All Communities → выбранное сообщество не должно добавлять ещё один All Communities и позволять бесконечно наслаивать одинаковые destinations. Это отдельный bug-fix PR. Не commit/push без команды пользователя.

## Repository context and required reading

Проверь dirty worktree и сохрани чужие изменения. Полностью прочитай `docs/ai/AGENTS.md`, `docs/ai/PROJECT.md`, `docs/ai/DECISIONS.md`, `docs/ai/DESIGN_SYSTEM.md`, `ARCHITECTURE.md`, `DESIGN.md`. Исследуй `CommunitiesListView`, private `AllCommunitiesView`, `CommunityDetailRoute`, `CommunityDetailView`, `MainTabView`, coordinator callbacks и существующие navigation tests. iOS 16+, SwiftUI, MVVM + Repository; navigation state остаётся presentation responsibility.

## Current state

Root использует `NavigationStack`, value-based `CommunityDetailRoute` и отдельный boolean `.navigationDestination(isPresented:)` для All Communities. `AllCommunitiesView` содержит `NavigationLink(value:)`, который должен разрешаться тем же родительским stack. Смешивание boolean destination и value route — вероятная причина неправильного stack, но сначала воспроизведи и подтверди фактический path/destination ownership.

## Implementation requirements

- Переведи Communities navigation на один явный typed route/path source of truth. Например, route enum различает `.allCommunities` и `.communityDetail(id:name:)`; выбери минимальное решение, совместимое с iOS 16 и текущей архитектурой.
- Root → See All добавляет ровно `.allCommunities`; All → Community добавляет ровно detail поверх него. Back из detail возвращает в существующий All, следующий Back — в root Communities.
- Переходы из Suggested/New/Search root должны открывать detail напрямую и Back возвращать root, без скрытого All.
- Повторный быстрый tap и повторный selection одного ID не должны дублировать destination. Не ломай deep-link/group-chat routing или `onCommunitySelected` refresh callback.
- Не добавляй nested `NavigationStack`, глобальный router, новый dependency или `.id(UUID())` workaround. Не меняй UI карточек и data loading.

## Tests and verification

Добавь тестируемую route/path policy либо navigation state tests: root→detail, root→all→detail→back→all→back→root, repeated tap, two different details sequentially и state restoration если текущий stack её поддерживает. Build, релевантные tests и `git diff --check`.

Вручную повтори проблемный сценарий минимум пять циклов, а также Suggested/Search → detail, create sheet, group chat и tab switching.

## Definition of Done and final response

Ни один пользовательский action не добавляет All Communities поверх самого себя; back stack всегда предсказуем; один destination зарегистрирован для каждого route type. В финале опиши подтверждённую root cause, route model, файлы, tests/manual checks и ограничения. Не commit/push.

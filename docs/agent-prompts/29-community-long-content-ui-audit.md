# PR 29 — Community long name and description UI audit

## Role and objective

Ты senior SwiftUI UI/accessibility engineer. Создай ветку `codex/community-long-content-ui-audit`. Исправь поломки интерфейса при длинных name/description во всех community surfaces. Этот PR шире prompt 25: он покрывает создание, списки, navigation titles, detail header и edit form; если PR 25 уже слит, сохрани его More-sheet behavior и не реализуй заново. Не commit/push.

## Repository context and required reading

Проверь `git status`, сохрани чужие изменения. Полностью прочитай `docs/ai/AGENTS.md`, `docs/ai/PROJECT.md`, `docs/ai/DECISIONS.md`, `docs/ai/DESIGN_SYSTEM.md`, `ARCHITECTURE.md`, `DESIGN.md`. Исследуй `Community`, mapper/repository/rules, `CreateCommunitySheet`, unified edit form если уже существует, `CommunitiesListView`, `SuggestedCommunityCard`, `CommunityRowView`, `CommunityDetailRoute/View`, chat/community title consumers и Stitch community references.

## Current state and product policy

Сначала найди фактические backend/UI limits; не придумывай несовместимые значения. Если лимитов нет, введи единый централизованный presentation/input policy: trim outer whitespace, reject empty name, ограничить name до 60 Unicode grapheme clusters и description до 1,000 grapheme clusters. Применяй одинаковую validation policy в create/edit и repository boundary; старые документы длиннее лимита должны безопасно отображаться и оставаться читаемыми, а не перестать загружаться.

## Implementation requirements

- Create/Edit: multiline-safe fields, live counters near limit, inline error, Save/Create disabled для invalid input, keyboard scrolling и защита от вставки огромного текста без crash.
- Suggested card/list/search: name не выталкивает artwork/count/chevron; используй подходящие `lineLimit`, reserved vertical space и truncation без fixed font shrink до нечитаемого размера.
- Detail: длинное name не дублируется разрушительно между navigation title/header, допускает 2–3 строки в content header, сохраняет Join/Chat/Edit controls и корректный layout на narrow width.
- Description: compact preview + More/full text по prompt 25; если PR 25 отсутствует, включи его требования в этот PR. Long unbroken strings/URLs, emoji, combining marks, newlines и RTL не создают horizontal overflow.
- Chat titles/routes получают безопасное display name, но сохранённое значение сообщества не мутируется ради UI.
- Не меняй дизайн-систему, community media, navigation stack policy PR 28 или storage model кроме validation rules, необходимых для согласованности.

## UI/accessibility requirements

Sunset Parchment, `screenHorizontal=20`, Dynamic Type до accessibility sizes, VoiceOver без повторного чтения truncated/full text, landscape и iPhone SE width. Не используй `minimumScaleFactor` как основной способ исправления body/headline text.

## Tests and verification

Unit tests для grapheme-aware validation/trim и create/edit ViewModels: boundary 0/1/60/61, description 1000/1001, emoji/combining marks, legacy oversized display. Build/tests/`git diff --check`. Manual matrix для root cards, All Communities, search results, detail, Create/Edit, community chat title, light/dark и largest Dynamic Type.

## Definition of Done and final response

Ни один community screen не overflow/overlap/обрезает controls из-за длинного контента; новые invalid значения не сохраняются; legacy данные отображаются безопасно. В финале перечисли выбранные limits и источник решения, изменённые surfaces/files, tests/manual checks и связь с PR 25. Не commit/push.

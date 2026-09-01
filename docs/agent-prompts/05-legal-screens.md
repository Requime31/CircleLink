# PR 05 — Terms and Privacy screens

## Objective and boundaries

Создай `codex/legal-screens`. Добавь локальные Terms of Service и Privacy Policy, общий native document screen и активные переходы из Age Gate и Settings. Это продуктовые черновики, не юридическая консультация. Не commit/push.

## Context

Проверь `git status`; прочитай полностью AI docs, `ARCHITECTURE.md`, `DESIGN.md`, Settings/AgeGate navigation и существующий Stitch settings reference. Сохрани iOS 16+, MVVM conventions и дизайн Sunset Parchment. Не трогай auth consent/storage и backend.

## Requirements

Определи Foundation-модель legal document (`title`, `lastUpdated`, sections) и один переиспользуемый SwiftUI reader с системной navigation, selectable text где уместно, scroll, headings и accessibility. Добавь два локальных английских документа: Terms и Privacy. Они должны покрывать назначение сервиса, user content/conduct, moderation/blocking, age 18+, account deletion, data categories, Firebase/Supabase/push, retention, support contact placeholder и изменение условий. В UI явно пометь контент как draft requiring legal review перед production; не придумывай компанию, адрес, сроки или права, которых нет в проекте.

В Age Gate фраза agreement содержит две раздельные кнопки/ссылки с доступными labels. В Settings добавь destinations, не дублируя строки, если settings foundation уже существует. Navigation должна работать и до авторизации. Не открывай web URLs и не добавляй package.

## Tests and verification

Добавь tests на наличие обоих документов, непустые обязательные sections и уникальные IDs; если navigation тестировать нечем, опиши manual checks. Build, unit tests, `git diff --check`. Проверь Dynamic Type, VoiceOver rotor/headings, dark mode если foundation доступен, small screen.

## Done

Оба документа доступны из нужных мест, reader не обрезает текст, draft маркирован, app собирается. Финал содержит files, содержание на уровне разделов, проверки и placeholders для legal review. Не commit/push.

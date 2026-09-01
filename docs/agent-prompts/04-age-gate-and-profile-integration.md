# PR 04 — Age Gate and profile integration

## Objective

Создай `codex/age-gate-profile-integration`. Используй готовые `birthDate` и repository API из PR 03: Age Gate принимает полную дату, Profile Setup автоматически показывает вычисленный возраст, а Profile Edit позволяет изменить birth date. Не commit/push.

## Required reading and prerequisite

Сохрани dirty changes. Прочитай полностью AI docs, `ARCHITECTURE.md`, `DESIGN.md`; изучи AgeGate/Profile views, view models, forms, coordinator, DI и tests, а также Stitch `age_gate`. Если `User.birthDate` и repository save API отсутствуют, остановись. Архитектура: iOS 16+, `@MainActor` ViewModels, Repository DI, cancellation/stale-session guards.

## Requirements

Замени year text field на компактный SwiftUI `DatePicker` с date-only semantics, диапазоном от разумной максимальной даты в прошлом до даты ровно 18 лет назад. Проверяй точные completed years, не разницу годов. `AgeGateViewModel` хранит выбранную дату, валидирует, атомарно подтверждает возраст и затем fetches profile как текущий flow.

Profile Setup не спрашивает возраст повторно: показывает автоматически рассчитанное значение из birth date. Если legacy confirmed user не имеет birthDate, оставь текущий editable age fallback и предложи дату позже, не блокируя вход. В Profile Edit добавь редактирование даты; перед сохранением покажи подтверждение, потому что меняется публичный возраст. Нельзя сохранить дату младше 18 или future. Уважай Sunset Parchment, Dynamic Type, VoiceOver и locale date formatting; не показывай raw ISO.

Не меняй Firestore schema, legal copy и другие profile fields.

## Tests and verification

Обнови AgeGate/Profile ViewModel tests: exact boundary, leap day, invalid date, repository error, duplicate taps, session change/cancellation, prefill, legacy fallback и edit recalculation. Собери проект, запусти targeted/full tests, `git diff --check`. Вручную проверь locale, keyboard absence, small screen и accessibility sizes.

## Definition of Done

Дата вводится один раз, age prefilled и пересчитывается, legacy flow не ломается, async state безопасен. Финал: files, behavior, tests, manual checks, known risks. Не commit/push.

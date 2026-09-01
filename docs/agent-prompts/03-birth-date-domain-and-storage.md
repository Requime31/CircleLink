# PR 03 — Birth date domain and storage

## Role and objective

Создай ветку `codex/birth-date-domain-storage`. Добавь приватную полную дату рождения в Domain/Data и точный расчёт возраста, сохранив совместимость со старыми профилями. UI Age Gate/Profile не переделывай. Не commit/push.

## Context and reading

Проверь dirty worktree. Полностью прочитай `docs/ai/AGENTS.md`, `PROJECT.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `DESIGN.md`; исследуй `User`, `User+Profile`, `UserRepository`, `FirestoreUserMapper`, `FirestoreUserRepository`, stubs/mocks, Firestore rules и AgeGate/Profile tests. Сохрани MVVM → Repository и pure Foundation Domain.

## Data/API decisions

Добавь `birthDate: Date?` в `User`. Firestore поле называется `birthDate` и хранится Timestamp в приватном user document; никогда не включай его в публичные connection/chat DTO сверх уже доступного профиля. Добавь repository operation для сохранения даты рождения вместе с `ageConfirmedAt`, атомарно насколько позволяет текущая схема. Не доверяй переданному клиентом `age` как источнику истины.

Создай pure helper для возраста: completed years относительно переданной reference date и calendar/time zone; future dates и невозможные/младше 18 значения валидируются вызывающим flow. Для публичного `User.age` mapper вычисляет возраст из `birthDate`; если даты нет, читает legacy `age`. При записи нового значения сохраняй birthDate и производное age для совместимости существующих queries/UI. Не удаляй legacy fields и не заставляй уже confirmed legacy users проходить gate снова.

Обнови stubs, mocks, fixtures, rules и setup/schema docs. Не добавляй UI, migration job или новый framework.

## Tests and verification

Покрой mapper round-trip, отсутствующую/невалидную дату, legacy age fallback, день до/в день/после birthday, 29 февраля и разные calendars/time zones. Выполни targeted Swift tests, полный build, `git diff --check`; если Firebase emulator отсутствует, явно укажи это.

## Done and report

Готово, когда старые документы читаются, новые сохраняются без потери данных, возраст считается детерминированно и Domain не импортирует Firebase/SwiftUI. В финале перечисли schema/API changes, файлы, тесты и migration compatibility. Не commit/push.

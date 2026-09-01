# PR 20 — Connect reminders

## Objective

Создай `codex/connect-reminders`. Реализуй ежедневное локальное напоминание проверить Connect activity с Enable Reminders и Reminder Time. Это отдельно от push Notifications. Не commit/push.

## Context

Проверь worktree; прочитай AI docs, architecture/design, Settings PR 19, `PushNotificationHandler`, AppDelegate permissions, existing notification preference/tests. iOS 16+, dependency injection; Views не вызывают `UNUserNotificationCenter` напрямую.

## Requirements

Введи `ReminderScheduling` protocol и production adapter. Persist локально `enabled` и date components (hour/minute), default разумное вечернее время, но не включай без consent. При enable: проверить/request notification authorization в user-initiated context; authorized → schedule one repeating calendar notification with stable identifier; denied → оставить off и предложить system settings. Изменение time атомарно replaces pending request; disable removes only reminder identifier, не push token/other notifications. Reconcile persisted state with system pending/authorization on Settings appear.

Copy нейтральный: проверить новые connections/Connect activity, без ложного утверждения о новых likes. Учитывай local timezone/calendar/DST через `UNCalendarNotificationTrigger`; не вычисляй fixed UTC. Settings UI показывает toggle, time picker только enabled, progress/error.

## Tests/Done

Fake scheduler tests: enable authorized/notDetermined/denied, schedule components, reschedule, disable, permission revoked, duplicate calls, persistence. Build/manual permission states/time change/relaunch, `git diff --check`. Готово без влияния на push preference. Финал: API/files/tests/manual limitations. Не commit/push.

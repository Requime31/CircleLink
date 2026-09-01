# PR 07 — Account deletion UI and recovery

## Objective

Создай `codex/account-deletion-ui-recovery`. Поверх PR 06 добавь Settings danger flow, деактивацию/выход и recovery gate при повторном входе в течение 30 дней. Не реализуй server cleanup. Не commit/push.

## Context and prerequisite

Проверь worktree и прочитай полностью AI docs, architecture/design docs, Settings, AuthViewModel/FirebaseAuthRepository, AppCoordinator/root routes, AppDependencies и tests. Нужны account state + request/restore repository API; иначе остановись. Следуй `@MainActor`, stale-session guards и MVVM + Repository.

## Requirements

Добавь в Settings Account/Danger Zone строку Delete Account. Первый экран объясняет: профиль скрывается сразу, восстановление возможно 30 дней, затем данные очищаются; сообщения/посты могут остаться анонимными. Требуется destructive confirmation с явным действием, progress, error и защита от double tap. При Firebase recent-login error запускай минимальный reauthentication flow, соответствующий исходному provider (Apple/email); не проси и не храни пароль без необходимости. После успешного request — sign out и reset coordinator state.

Во время bootstrap/sign-in обнаруживай deactivated current profile и показывай отдельный root recovery screen вместо main tabs. Он отображает deadline, Restore Account и Sign Out/Delete as scheduled. Restore вызывает repository, refetches profile и продолжает обычные age/profile gates. Просроченный аккаунт нельзя восстанавливать клиентом: показать понятное состояние и Support action.

UI следует Sunset Parchment, dark mode при наличии, Dynamic Type/VoiceOver. Не реализуй Admin deletion, legal docs или общую Settings переработку.

## Tests and Done

Покрой ViewModels/coordinator: success, cancel, recent-login, errors, duplicate taps, session swap, recovery, expired deadline, restore routing. Build, tests, `git diff --check`; вручную Apple/email flows и relaunch. Готово, когда deactivation немедленно завершает session, deactivated login не попадает в tabs, restore работает безопасно. В финале файлы, проверки и непроверенные provider cases. Не commit/push.

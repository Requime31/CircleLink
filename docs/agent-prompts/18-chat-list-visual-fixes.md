# PR 18 — Chat list visual fixes

## Objective

Создай `codex/chat-list-visual-fixes`. Сделай Hidden Chats entry спокойнее и исправь растягивание profile images во всех chat avatar contexts. Только UI fixes. Не commit/push.

## Context

Проверь dirty tree; полностью прочитай AI docs, `ARCHITECTURE.md`, `DESIGN.md`, `DESIGN_SYSTEM.md`; открой Stitch `chats_clean_header/screen.png`. Исследуй `AvatarImageView`, ChatListRow, MessageCell, ChatInfo/Participants, HiddenChats и image loader/reuse. Canonical: avatars are squircles everywhere.

## Requirements

Hidden Chats row должен выглядеть как обычная tertiary navigation row: system/body typography, ясная archive/eye-slash symbol, restrained `surfaceSoft`, понятная форма, count secondary text, без oversized badge/Android pill. Сохрани доступность даже при zero hidden; не превращай в toolbar button.

Унифицируй avatar rendering: fixed square frame, aspect fill, clipping before/with `CLAvatar.shape`, no distortion; placeholder initials/symbol uses same mask. UIKit `UIImageView.contentMode = .scaleAspectFill`, constraints square, image reset/cancel in `prepareForReuse`. Проверь URL, base64, local preview, portrait/landscape/square/corrupt/missing data. Не меняй image storage/compression или форму Connect controls.

## Verification/Done

Добавь pure sizing/loader tests только если current abstraction позволяет; не вводи snapshot framework. Build/tests, визуальная матрица list/thread/info/participants light/dark/Dynamic Type, rapid scroll reuse, `git diff --check`. Готово без distortion, stale image flash и visual dominance Hidden row. Финал: files, root cause, manual matrix, tests. Не commit/push.

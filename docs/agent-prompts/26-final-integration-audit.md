# PR 26 — Final integration audit

## Role and objective

Ты senior release engineer/code reviewer. Создай `codex/final-integration-audit`. Проведи интеграционный аудит выбранных PR 01–25 и дополнительных bugfix PR 27–29; исправь только доказанные небольшие integration defects. Новые features, redesign и schema invention запрещены. Не commit/push.

## Required reading and inventory

Проверь `git status`, current branch/history и сохрани пользовательские изменения. Полностью прочитай AI docs, `ARCHITECTURE.md`, `DESIGN.md`, Firebase/Supabase/worker setup. Определи, какие planned PR реально слиты: не считай отсутствующую feature дефектом и не реализуй её. Составь короткую traceability matrix present/missing before edits.

## Audit areas

- Build iOS 16+; Swift concurrency/MainActor/cancellation/session guards.
- MVVM → Repository, manual DI, pure Domain, no Firebase/UserDefaults/system centers in Views.
- Firestore mapper/rules/index compatibility for birthDate, deactivation, outgoing likes, pin metadata; legacy docs.
- Node cleanup idempotency/dry-run/no PII and no Cloud Functions assumption.
- Navigation: deactivated recovery, legal before auth, Matches direct chat, author profile, Settings routes.
- State: blocked/deactivated filtering, mute order, pin/hidden invariants, optimistic rollback.
- UI: System/Light/Dark, UIKit chat, Dynamic Type, VoiceOver, Reduce Motion, contrast, avatars, long descriptions, small screens.
- Privacy/security: birth date exposure, support payload, logs/secrets, deletion copy vs actual behavior.

Fix only local issues with clear reproduction/test; for larger mismatch write a blocking finding and leave code unchanged. Do not modify unrelated docs/format whole project.

## Verification

Run full Swift test suite and generic simulator build, `npm test` in worker if relevant, rules/index validation available locally, `git diff --check`. Manual smoke: auth→age/profile→tabs; Connect lists/match/block; chat pin/mute/hide/direct/group; community create/edit/header/posts; Settings/theme/reminder/legal/delete/recovery. Record commands and failures exactly.

## Definition of Done and final response

No known P0/P1 integration defect remains; each edit has regression evidence; missing prerequisites are reported, not implemented. Final response: present/missing PR matrix, findings by severity, changed files and reasons, commands/results, manual coverage, residual risks. Never claim unrun checks. Не commit/push/deploy.

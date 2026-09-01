# PR 24 — Unified Create/Edit Community form

## Objective

Создай `codex/community-form-redesign`. Переделай Create Community и объедини Edit cover/name/description в одну общую form experience с единым Save. Сохрани repositories, storage и permissions. Не commit/push.

## Context

Проверь worktree. Прочитай полностью AI docs, architecture/design, `CreateCommunitySheet`, `CommunityDetailView/ViewModel`, CommunitiesViewModel, Community/ImageStorage repositories, rules/tests; открой Stitch `communities_updated`, `community_detail_feed`, `suggested_communities` и релевантный code.html только как visual reference. Не копируй HTML.

## Requirements

Создай shared form content/state только там, где это реально убирает duplication; create/edit сохраняют отдельные intents. Поля: cover hero with add/change/remove affordance, name, description, inline validation, character counters из фактических current limits. Edit prefilled и одним Save атомарно координирует metadata + optional Supabase image operation с понятным partial-failure recovery; не обещай транзакцию между Firestore/Supabase, если её нет. Create сохраняет существующий ownership/membership creation flow.

Layout выразительный, но native Sunset Parchment: clear hero, спокойные sections, soft CTA, no decorative overload, `screenHorizontal=20`. Keyboard, photo picker cancellation, upload progress/errors, double submit, unsaved dismissal confirmation. Remove cover только если repository уже поддерживает; иначе не показывай ложное действие и зафиксируй limitation.

Не менять Community domain schema, permissions, discovery cards или detail header beyond integration entry.

## Tests/Done

Tests create/edit prefill/validation, image unchanged/replace/remove support, metadata/image failures, duplicate save, permission. Build/manual small screen/Dynamic Type/dark mode/photo picker, `git diff --check`. Готово, когда owner редактирует cover/name/description в одном sheet и create не regress. Финал: files, flow, partial-failure policy, tests. Не commit/push.

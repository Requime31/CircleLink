---
id: adr-process-branching-and-release-flow
title: Branching and Release Flow
type: decision
status: accepted
date: 2026-09-11
tags: [process, git, github, release]
sources:
  - ../../raw/conversations/2026-09-11-llm-wiki-requirements.md
---

# Branching and Release Flow

## Context

The previous documentation treated `develop` as daily integration, while the owner wanted a clear
stage between working branches and a stable candidate. The proposed name `developer` did not
communicate that role.

## Decision

Working `codex/*`, `feature/*`, and `fix/*` branches merge into `integration`. Stabilized work moves
from `integration` to `develop`; releases move from `develop` to `main`. GitHub Issues own work,
Project `CircleLink Development` owns workflow state, and release Milestones group delivery.

Hotfixes start at `main` and reconcile back into both lower stages. Wiki decisions and code travel
together. The current local `developer` branch is renamed to `integration` as part of this change.

## Consequences

Branch purpose is explicit, at the cost of maintaining one additional promotion stage. Required
checks can become stricter at `develop` and `main` while `integration` remains the daily merge target.

## Sources

- [Curated CircleLink requirements](../../raw/conversations/2026-09-11-llm-wiki-requirements.md)
- [Development workflow](../../process/development-workflow.md)

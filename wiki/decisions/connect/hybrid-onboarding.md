---
id: adr-connect-hybrid-onboarding
title: Connect Hybrid Onboarding
type: decision
status: implemented
date: 2026-09-10
tags: [connect, onboarding, ux, motion]
sources:
  - git:6340b52
---

# Connect Hybrid Onboarding

## Context

The original Connect guide outlined the candidate card and described both gestures in one modal.
It could appear before content settled and did not let a new user safely practice the interaction.

## Decision

Keep “Meet someone new” as the first message without a card outline. Then demonstrate pass, require
a safe left-swipe practice, demonstrate say hi, require a safe right-swipe practice, and finish with
a ready action. Practice never acts on the real candidate. The deck remains fixed during motion and
supports Reduce Motion, Dynamic Type, and accessibility actions.

The introductory guide stays suspended through the entire feature-owned tutorial and persists
completion only at the end.

## Consequences

First use takes more steps but teaches the actual gesture without destructive side effects or
layout movement. The state machine and guide handoff require regression coverage.

## Sources

- [Connect](../../product/connect.md)
- Stable implementation commit `6340b52`.
- `CircleLink/Features/Connect/ConnectTutorialController.swift`.

---
id: adr-connect-profile-image-rendering
title: Profile Images Preserve Their Aspect Ratio
type: decision
status: implemented
date: 2026-09-10
tags: [connect, profile, images, ui]
sources:
  - ../../raw/conversations/2026-09-11-llm-wiki-requirements.md
---

# Profile Images Preserve Their Aspect Ratio

## Context

Shared profile images used aspect-fill inside containers with several ratios: a tall Connect deck,
4:5 peer profile, 3:4 Liked You cards, and square avatars. Although aspect-fill preserves geometry,
large center cropping and inconsistent zoom made people appear stretched or incorrectly framed.

## Decision

Use aspect-fit for both hero profile photos and compact profile avatars. Keep existing container
dimensions so Connect swipe layout and grids remain stable. Fill unused space with the shared soft
surface color. Post media and chat attachments remain outside this decision.

## Alternatives considered

- Aspect-fill with user-controlled focal-point metadata: stronger full-bleed composition but more
  data and editing complexity.
- Dynamic containers matching every source image: rejected because Connect and grids would move.
- Aspect-fit over a blurred duplicate: deferred because the owner selected direct aspect-fit.

## Consequences

The full source image remains visible without geometric distortion or layout changes. Letterbox or
pillarbox space is expected when source and container ratios differ.

## Sources

- [Curated requirements](../../raw/conversations/2026-09-11-llm-wiki-requirements.md)
- `CircleLink/Shared/Avatar/ProfileHeroImageView.swift` — `ProfileHeroImageView`.
- `CircleLink/Shared/AvatarImageView.swift` — `AvatarImageView`.

---
id: adr-profile-private-birth-date
title: Keep Full Birth Date Private
type: decision
status: implemented
date: 2026-09-01
tags: [profile, privacy, firestore]
sources:
  - git:0b8696f
  - legacy:ARCHITECTURE.md
---

# Keep Full Birth Date Private

## Context

Age confirmation needs a full date, but other users and copied public profile data need only a
derived age.

## Decision

Store the canonical Gregorian UTC-noon birth date only at `users/{uid}/private/account`. Store only
derived `age` and confirmation metadata on the public profile. Never copy birth date into chats,
connections, or other public documents. Legacy age-only profiles remain supported.

## Consequences

The app performs explicit local-date conversion at the UI boundary and coordinated private/public
writes. The full birth date is protected by owner-only rules.

## Sources

- [Profile and account](../../product/profile-and-account.md)
- `CircleLink/Data/Firebase/FirestoreUserRepository.swift`.
- Integration commit `0b8696f`.

---
id: adr-profile-reversible-account-deactivation
title: Reversible Account Deactivation
type: decision
status: implemented
date: 2026-09-01
tags: [profile, account, lifecycle, firestore]
sources:
  - git:0b8696f
  - legacy:ARCHITECTURE.md
---

# Reversible Account Deactivation

## Context

The iOS client cannot safely perform complete recursive data cleanup and Firebase Auth deletion.
Users need a recovery period after requesting deletion.

## Decision

Deletion requests soft-deactivate the account and record authoritative lifecycle timestamps. Social
interactions require active participants. A returning deactivated session routes only to account
recovery. Restore reactivates and refetches the profile. Physical cleanup after the recovery window
requires an external trusted service; the client does not claim completion.

## Consequences

Deletion is reversible and rules can consistently hide inactive accounts. Actual erasure remains
an operational dependency that must be implemented and validated separately.

## Sources

- [Profile and account](../../product/profile-and-account.md)
- `CircleLink/Features/Settings/AccountDeletionView.swift`.
- `CircleLink/Data/Firebase/FirestoreUserRepository.swift`.
- Integration commit `0b8696f`.

---
title: Profile and Account
type: product
status: current
updated: 2026-09-11
tags: [product, profile, account]
---

# Profile and Account

Profiles contain public identity fields, interests, derived age, avatar data, and profile posts.
The full birth date is private and stored separately from the public profile. Profile images are
compressed for Firestore storage; profile-post image binaries use Supabase Storage.

Account deletion is a reversible deactivation request. The public account state becomes
`deactivated`, lifecycle timestamps are recorded privately, and the app routes returning sessions
to recovery. Physical cleanup and Firebase Auth deletion require an external cleanup service and
are not performed by the iOS client.

## Related decisions

- [Private birth date](../decisions/profile/private-birth-date.md)
- [Reversible account deactivation](../decisions/profile/reversible-account-deactivation.md)
- [Profile image rendering](../decisions/connect/profile-image-rendering.md)

## Sources

- `CircleLink/Features/Profile/`.
- `CircleLink/Data/Firebase/FirestoreUserRepository.swift`.
- `CircleLink/Domain/Models/User.swift`.

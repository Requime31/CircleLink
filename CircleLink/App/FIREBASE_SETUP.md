# Firebase Setup (Phase 1+)

CircleLink uses Firebase for **Auth**, **Firestore**, and **FCM** (Messaging).
**Spark plan is enough** — do not deploy Cloud Functions / Blaze.

Chat image binaries are **not** in Firebase Storage — see [SUPABASE_SETUP.md](SUPABASE_SETUP.md).

## 1. Add Firebase iOS SDK (SPM)

Already configured in `CircleLink.xcodeproj`:

- `FirebaseCore`
- `FirebaseAuth`
- `FirebaseFirestore`
- `FirebaseMessaging` (Phase 9 push)

If packages are missing locally: **File → Packages → Resolve Package Versions**.

## 2. Add GoogleService-Info.plist

1. Create a project in [Firebase Console](https://console.firebase.google.com)
2. Add an iOS app with bundle ID: `com.roman.helloswift.CircleLink`
3. Download `GoogleService-Info.plist`
4. Drag into the `CircleLink` target (copy items, target membership checked)

> **Git:** `GoogleService-Info.plist` is in `.gitignore` (contains API keys).
> Template: `CircleLink/GoogleService-Info.plist.example`  
> `cp CircleLink/GoogleService-Info.plist.example CircleLink/GoogleService-Info.plist`

## 3. Enable Auth providers (Firebase Console)

**Authentication → Sign-in method:**

- Enable **Email/Password**
- Enable **Apple**
  - Add Apple Service ID / key if required for production
  - For development, native iOS Sign in with Apple works with Firebase Apple provider enabled

## 4. Enable Sign in with Apple (Xcode + Apple Developer)

1. Xcode → Target **CircleLink** → **Signing & Capabilities** → **+ Capability** → **Sign In with Apple**
2. Apple Developer portal → App ID → enable **Sign In with Apple**
3. Regenerate provisioning profile (automatic signing usually picks this up)

`CircleLink.entitlements` already contains:

```xml
<key>com.apple.developer.applesignin</key>
```

**Device build fails** if the provisioning profile does not include this capability.

## 5. Firestore

Create Firestore database (test mode OK for development).

User documents path: `users/{userId}`

Public profile fields:

- `displayName`, `avatarURL`, `avatarBase64`, `interests`, `age`, `ageConfirmedAt`, `createdAt`
- `accountState` — `active` or `deactivated`; missing legacy values mean `active`

Account deletion request atomically changes `accountState` to `deactivated`, records the
request time, and schedules cleanup 30 Gregorian UTC calendar days later. Restore changes
the state back to `active` and removes the lifecycle marker. Only the authenticated owner may
change these fields. Physical cleanup and Firebase Auth deletion cannot be performed by the
iOS client. No physical-cleanup worker is included in this repository, so deactivated accounts
remain recoverable until an external cleanup service is provided. The rules reserve the
server-only `cleanupClaimedAt` field for such a future service.

Private account document path: `users/{userId}/private/account`

- `birthDate` — full date stored as a canonical Gregorian UTC-noon Firestore Timestamp; owner-only read/write
- `deletionRequestedAt` — authoritative server commit time; the cleanup deadline is derived as +30 days
- `fcmToken`, `fcmTokenUpdatedAt` — owner-only push delivery data

Convert this stored value with `AgeCalculator.localDate(fromPersistedBirthDate:)` before
binding it to a local `DatePicker`; convert picker input back with
`canonicalBirthDate(fromLocalDate:)`.

Age confirmation writes the private `birthDate` and public derived `age` + `ageConfirmedAt`
in one Firestore batch. Legacy profiles without `birthDate` continue using the public `age`
field and an existing `ageConfirmedAt`; no migration job is required. Never copy `birthDate`
into connection, chat, or other public profile documents.

### Avatars (Phase 3, no Storage required)

Avatars are stored as **compressed JPEG base64** in Firestore field `avatarBase64`.
This works on the free Spark plan — Firebase Storage is **not** required.

### Chat images (Phase 6 — Supabase Storage)

Chat image attachments are stored in **Supabase Storage** (free tier).
Firestore message documents store only `imageURL`.

See [SUPABASE_SETUP.md](SUPABASE_SETUP.md) for bucket and API key setup.

### Per-user chat metadata

Chat list preferences live at `users/{userId}/chatRefs/{chatId}` and never on the
shared `chats/{chatId}` document:

- `muted`, `hidden`, `hiddenAt`, `clearedAt` — existing owner preferences
- `pinned: Bool` — whether a visible chat is pinned
- `pinOrder: Int` — optional zero-based manual order for pinned chats

Unpinning and hiding remove `pinOrder`. Reordering writes the complete pinned set in
one Firestore batch. A peer may update only preview fields (`lastMessageText` and
`lastMessageAt`) and cannot change another user's pin metadata.

`chatRefs.lastMessageAt` must be the exact `Timestamp` from the parent
`chats/{chatId}.lastMessageAt`. Do not convert an existing Firestore timestamp through Swift
`Date` before writing a ref: nanosecond precision can change and the strict rules equality check
will reject only the affected documents. For a legacy chat without `lastMessageAt`, write the
parent timestamp first and reuse that same value for its refs.

### Communities

Community documents path: `communities/{communityId}`

Fields:

- `name`, `description`, `interestTag`, `memberCount`, `coverImageURL`, `createdAt`, `createdBy`

Member documents path: `communities/{communityId}/members/{userId}`

Fields:

- `joinedAt`, `role` (`member` | `admin`)

Signed-in users create a community in the app (`CreateCommunitySheet`). The creator is stored as `createdBy` and joined as `admin` in the same batch write.

`join` / `leave` update the member subcollection and increment/decrement `memberCount` atomically via batch write.

### Firestore Security Rules (required for Phase 5)

If the app shows **"Missing or insufficient permissions"**, use the failing path in the Xcode
console to identify the relevant rule. A failure under `users/{uid}/chatRefs/{chatId}` can indicate
a legacy schema or a timestamp that does not exactly match the parent chat.

**Option A — Firebase Console (fastest)**

1. [Firebase Console](https://console.firebase.google.com) → your project → **Firestore Database** → **Rules**
2. Paste the contents of `firestore.rules` from the repo root
3. Click **Publish**

**Option B — Firebase CLI**

```bash
firebase deploy --only firestore:rules
```

Rules summary:

| Path | Who | Action |
|------|-----|--------|
| `users/{userId}` | signed-in user | read any profile; write own profile |
| `communities/{id}` | signed-in user | read list/detail; **create** (`createdBy` = self, `memberCount` == 1); update `memberCount` only |
| `communities/{id}/members/{userId}` | signed-in user | read members; create/delete **own** membership |

Communities can be created and edited in the client. Firestore stores metadata; Supabase
stores cover/post image binaries. The checked-in rules restrict metadata edits to the creator
and membership count transitions to matching member-document writes.

## 6. Verify

On launch, check Xcode console:

- `[CircleLink] Firebase configured.` — OK
- `GoogleService-Info.plist not found` — add the plist

## 7. Test Email/Password

Create a test user in Firebase Console → Authentication → Users → Add user.

## 8. Push Notifications / FCM (Phase 9)

### Xcode / Apple Developer

1. Target **CircleLink** → **Signing & Capabilities** → **+ Capability** → **Push Notifications**
2. Background Modes → enable **Remote notifications** (also set via `INFOPLIST_KEY_UIBackgroundModes`)
3. Entitlements include `aps-environment` (`development` for Debug; Archive/Release may need `production` via automatic signing)
4. Apple Developer → Keys → create **APNs Auth Key** (`.p8`) if you do not have one

### Firebase Console

1. Project Settings → **Cloud Messaging** → Apple app → upload APNs Auth Key
2. Confirm the iOS app bundle ID matches: `com.roman.helloswift.CircleLink`

### App behavior

- Permission is requested when the user reaches **main tabs** after sign-in / age gate / profile setup (not on cold launch)
- On grant: APNs device token → FCM → `users/{userId}/private/account.fcmToken`
- Notification tap is routed only through `AppCoordinator` (Chat / Connect)

### Push sender

CircleLink stays on the Firebase **Spark** plan and does not include Cloud Functions or another
server-side FCM sender. The app registers tokens and handles notification taps, but background
push delivery requires a separately operated sender.

## Security notes (Phase 2)

- Firebase ID tokens stored in **Keychain** via `KeychainTokenStorage`
- **No tokens in UserDefaults**
- `signOut()` clears Keychain + Firebase session + FCM token
- Firebase SDK traffic is protected in transit by TLS, but chat text and `lastMessageText`
  are not end-to-end encrypted and remain readable to authorized project infrastructure.

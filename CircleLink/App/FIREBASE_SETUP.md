# Firebase Setup (Phase 1+)

CircleLink uses Firebase for Auth and Firestore (Spark plan OK).

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
> Use `GoogleService-Info.plist.example` as a template for other developers.

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

Fields used in Phase 2–3:

- `displayName`, `avatarURL`, `avatarBase64`, `interests`, `ageConfirmedAt`, `createdAt`

### Avatars (Phase 3, no Storage required)

Avatars are stored as **compressed JPEG base64** in Firestore field `avatarBase64`.
This works on the free Spark plan — Firebase Storage is **not** required.

### Chat images (Phase 6 — Supabase Storage)

Chat image attachments are stored in **Supabase Storage** (free tier).
Firestore message documents store only `imageURL`.

See [SUPABASE_SETUP.md](SUPABASE_SETUP.md) for bucket and API key setup.

### Communities (Phase 5)

Community documents path: `communities/{communityId}`

Fields:

- `name`, `description`, `interestTag`, `memberCount`

Member documents path: `communities/{communityId}/members/{userId}`

Fields:

- `joinedAt`, `role` (`member` | `admin`)

`join` / `leave` update the member subcollection and increment/decrement `memberCount` atomically via batch write.

### Firestore Security Rules (required for Phase 5)

If the app shows **"Missing or insufficient permissions"**, Firestore rules do not allow reads on `communities` yet.

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
| `communities/{id}` | signed-in user | read list/detail; update `memberCount` only |
| `communities/{id}/members/{userId}` | signed-in user | read members; create/delete **own** membership |

Communities are seeded manually in Console (no client-side create in MVP).

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

- Permission is **not** requested on launch
- First successful **message send** or **Connect** triggers the system permission dialog
- On grant: APNs device token → FCM → `users/{userId}.fcmToken`
- Notification tap is routed only through `AppCoordinator` (Chat / Connect)

### Cloud Functions

**Not used.** CircleLink stays on the Firebase **Spark** plan. FCM is sent by the Node push worker in `websocket-server` (Firestore `onSnapshot` → Admin Messaging). See [`websocket-server/README.md`](../../websocket-server/README.md).

The `functions/` folder is kept only as an unused Blaze-era reference — do not deploy it.

## Security notes (Phase 2)

- Firebase ID tokens stored in **Keychain** via `KeychainTokenStorage`
- **No tokens in UserDefaults**
- `signOut()` clears Keychain + Firebase session + FCM token

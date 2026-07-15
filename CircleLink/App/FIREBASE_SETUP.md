# Firebase Setup (Phase 1+)

CircleLink uses Firebase for Auth and Firestore (Spark plan OK).

## 1. Add Firebase iOS SDK (SPM)

Already configured in `CircleLink.xcodeproj`:

- `FirebaseCore`
- `FirebaseAuth`
- `FirebaseFirestore`

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

## 6. Verify

On launch, check Xcode console:

- `[CircleLink] Firebase configured.` — OK
- `GoogleService-Info.plist not found` — add the plist

## 7. Test Email/Password

Create a test user in Firebase Console → Authentication → Users → Add user.

## Security notes (Phase 2)

- Firebase ID tokens stored in **Keychain** via `KeychainTokenStorage`
- **No tokens in UserDefaults**
- `signOut()` clears Keychain + Firebase session

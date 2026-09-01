# DECISIONS.md — what’s true now

Living operational notes for agents. Prefer short, dated entries.  
Update when a decision lands or a workstream finishes.

Related: [AGENTS.md](AGENTS.md) · [PROJECT.md](PROJECT.md) · [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)

---

## 2026-09-01 — Connect deck and direct-chat compatibility hardening

| Area | Current truth |
|------|---------------|
| Connect deck identity | `ConnectViewModel` is the only source of `top` / `next` / `following`; the View stores animation offset only and does not mirror candidate order in local `@State` |
| Session Pass | Passed candidate IDs survive quiet/catalog refreshes and are cleared only by Undo or an explicit session reset |
| Say Hi | A failed request may deliberately restore its card; a request rejected before launch resets the animation without mutating deck order |
| Direct-chat bootstrap | A missing deterministic direct-chat document may be probed only by a participant in the corresponding accepted connection |
| Chat-ref timestamps | Mirror the exact Firestore `Timestamp` from `chats/{chatId}` into `users/{uid}/chatRefs/{chatId}`; never round-trip through `Date` before rules equality checks |
| Legacy chats | If an existing chat lacks `lastMessageAt`, normalize the parent chat first, then seed chat refs with the same timestamp |

The compatibility rules remain narrow: missing parent chats do not grant message access,
and chat refs cannot be used to change another user's personal mute/hide/pin metadata.

---

## 2026-08-31 — Integration batch moved to `ui-redisign`

The complete uncommitted integration working tree was moved from
`codex/final-integration-audit` to `ui-redisign`. No commit or push was created.

| Area | Current truth |
|------|---------------|
| Bootstrap | Branded animated `LoadingView`; Debug-only three-second review delay |
| Communities | Join/leave refreshes in place; membership button transitions without replacing the full screen; leave confirmation is a centered alert |
| Chats root | Static ink `Chats` content header; Hidden Chats owns an in-content search field so navigation chrome cannot clear the root header |
| Chat organization | UIKit implementation lives in `Features/Chat/`; lists/navigation remain in `Features/ChatList/` |
| Chat security | Firebase/Supabase transport uses TLS; messages are not E2EE and Firestore stores text/previews as readable fields |
| Account lifecycle | Private birth date/FCM token, soft deletion/recovery and external cleanup worker are implemented |
| Product additions | Dark appearance, reminders, legal/help/rating, blocked people, outgoing likes, pinning, community forms/media and content-policy hardening |

This entry supersedes the older “system large Chats title” note below. Chats retains large
visual hierarchy as a static content header rather than `navigationTitle`.

---

## 2026-08-20 — Apple Review readiness + canonical UI corrections (historical baseline)

Verified at `ui-redisign` commit `0bc0da8`:

| Area | Current truth |
|------|---------------|
| Avatars | **Squircle everywhere, including Chats.** The old Chats-circle exception is superseded. |
| Navigation | Communities, Chats, Profile use system large titles; Connect and push screens use inline. No clay/custom principal tab title. Chat thread may use principal as an info control. |
| Apple sign-in | Uses `ASAuthorizationAppleIDButton`; repository/presenter auth flow remains unchanged. |
| Moderation | Report/block is available from Connect and direct-chat context; blocked users are filtered from discovery. |
| Reliability | Async actions guard stale session/results; chat listener installation and termination are race-safe. |
| Privacy copy | Photo-library purpose includes chat attachments, posts, profile pictures, and community covers. |
| Communities | Create/cover editing and paginated member posts are live; Firestore metadata + Supabase binary storage. |

This entry supersedes conflicting avatar statements below. Its Chats navigation-title detail
is superseded by the 2026-08-31 integration entry.

---

## 2026-08-12 — Nav / Profile consistency pass (done)

Landed on `ui-redisign` via merge of `consistency/nav-profile-tabs` (branch deleted after merge):

| Change | Decision |
|--------|----------|
| Nav titles | Historical: large Communities/Profile, inline Connect/push, clay principal Chats. **Superseded on 2026-08-20** by system large Chats title. |
| Profile avatar | Removed decorative circle clay badge on squircle hero avatar (shape conflict with §0). |
| Interests | Keep `CLChip` Capsule language (already Capsule). |
| Profile tab icon | `person.circle` → `person` (less circle-leaning, familiar UX). |
| Untouched | Historical Chats circle avatars were later replaced by canonical squircles. Connect Pass / Say Hi / Back remain circles. |

---

## 2026-08-12 — Active branches / redesign context

| Item | State |
|------|--------|
| **`ui-redisign`** | Active visual/product integration line (Sunset Parchment). |
| **Stash** | May still hold `wip: unrelated before consistency/nav-profile-tabs` (Auth / AgeGate / ChatInfo / ProfileSetup). Restore carefully; unrelated to the consistency pass. |

**Guidance:** for new redesign UI, prefer branching from `ui-redisign`.

---

## Intentional design rules (locked)

From root `DESIGN.md` §0 — **not bugs**:

1. **All avatars are squircles**, including chat list / thread / chat info.
2. **Connect Pass / Say Hi / Back are circle buttons** — do not convert to squircle.
3. **Connect Discover hero** shows name + age only; bio belongs in About.
4. **Soft CTA is default**; solid clay is rare (FAB, Say Hi, unread accents).
5. **`screenHorizontal` = 20** on all screens.
6. **Tab-root titles are never clay/custom principal:** system large Communities/Profile,
   inline Connect, static ink content header Chats.

---

## Product / architecture decisions (stable)

| Decision | Note |
|----------|------|
| No UseCase layer | ViewModel → Repository |
| Chat transport on iOS | Firestore listeners (WebSocket client removed) |
| Push on Spark | `websocket-server/` FCM worker; do not rely on `functions/` for MVP |
| Images | Supabase Storage for chat attachments, profile-post images, community covers/posts |
| Community content | Firestore community/post documents + Supabase cover/post images |
| Chat UI | UIKit module under `CircleLink/Features/Chat/` |
| Design tokens | `CLTheme` / `CLColor` mirror `DESIGN.md` |
| Account deletion foundation | Soft deactivation in `users/{uid}` with a 30-day UTC-calendar grace period; cleanup/Auth deletion run through the external worker |
| Account deletion UI | Settings Danger Zone requests soft deletion, signs out immediately, and routes returning deactivated sessions to a recovery-only root screen |
| Account cleanup worker | External `websocket-server` CLI, not Cloud Functions; daily scheduler contract, atomic cleanup claim, source profile deleted last, authored content anonymized and preserved |

---

## AI docs (this folder)

| File | Role |
|------|------|
| `AGENTS.md` | How agents should behave |
| `PROJECT.md` | What the app is / where code lives |
| `DESIGN_SYSTEM.md` | Short visual memory → always defer to root `DESIGN.md` |
| `DECISIONS.md` | Current operational truth |

Historical: `docs/agent-prompts/` contains the integration prompt archive. Do not replay it
as a current plan; prefer this `docs/ai/` set + `DESIGN.md`.

---

## How to update this file

Add a dated bullet when you:

- lock a visual exception or policy,
- start/finish a named branch workstream,
- change DI / backend / navigation ownership in a way agents must know.

Keep entries short. Move stale “in progress” items to “done” or delete them.

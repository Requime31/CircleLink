# DECISIONS.md — what’s true now

Living operational notes for agents. Prefer short, dated entries.  
Update when a decision lands or a workstream finishes.

Related: [AGENTS.md](AGENTS.md) · [PROJECT.md](PROJECT.md) · [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)

---

## 2026-08-12 — Nav / Profile consistency pass (done)

Landed on `ui-redisign` via merge of `consistency/nav-profile-tabs` (branch deleted after merge):

| Change | Decision |
|--------|----------|
| Nav titles | **Large** = Communities + Profile; **Inline** = Connect + push screens; **Clay principal** = Chats root only. Documented in `DESIGN.md`. |
| Profile avatar | Removed decorative circle clay badge on squircle hero avatar (shape conflict with §0). |
| Interests | Keep `CLChip` Capsule language (already Capsule). |
| Profile tab icon | `person.circle` → `person` (less circle-leaning, familiar UX). |
| Untouched | Chat circle avatars; Connect Pass / Say Hi / Back circles. |

---

## 2026-08-12 — Active branches / redesign context

| Item | State |
|------|--------|
| **`ui-redisign`** | Main visual redesign line (Sunset Parchment). Includes nav title policy + Profile/tab consistency above. |
| **Stash** | May still hold `wip: unrelated before consistency/nav-profile-tabs` (Auth / AgeGate / ChatInfo / ProfileSetup). Restore carefully; unrelated to the consistency pass. |

**Guidance:** for new redesign UI, prefer branching from `ui-redisign`.

---

## Intentional design exceptions (locked)

From root `DESIGN.md` §0 — **not bugs**:

1. **Chats avatars are circles** (list / thread / chat info). Everywhere else defaults to squircle.
2. **Connect Pass / Say Hi / Back are circle buttons** — do not convert to squircle.
3. **Connect Discover hero** shows name + age only; bio belongs in About.
4. **Soft CTA is default**; solid clay is rare (FAB, Say Hi, unread accents).
5. **`screenHorizontal` = 20** on all screens.
6. **Clay principal nav title** is Chats-only (see Nav title policy in `DESIGN.md`).

---

## Product / architecture decisions (stable)

| Decision | Note |
|----------|------|
| No UseCase layer | ViewModel → Repository |
| Chat transport on iOS | Firestore listeners (WebSocket client removed) |
| Push on Spark | `websocket-server/` FCM worker; do not rely on `functions/` for MVP |
| Images | Supabase Storage for chat (and profile) images |
| Chat UI | UIKit module under `CircleLink/Chat/` |
| Design tokens | `CLTheme` / `CLColor` mirror `DESIGN.md` |

---

## AI docs (this folder)

| File | Role |
|------|------|
| `AGENTS.md` | How agents should behave |
| `PROJECT.md` | What the app is / where code lives |
| `DESIGN_SYSTEM.md` | Short visual memory → always defer to root `DESIGN.md` |
| `DECISIONS.md` | Current operational truth |

Superseded: old `docs/agent-prompts/` phase prompt packs (removed). Prefer this `docs/ai/` set + `.cursor/rules/` + `DESIGN.md`.

---

## How to update this file

Add a dated bullet when you:

- lock a visual exception or policy,
- start/finish a named branch workstream,
- change DI / backend / navigation ownership in a way agents must know.

Keep entries short. Move stale “in progress” items to “done” or delete them.

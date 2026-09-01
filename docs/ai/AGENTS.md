# AGENTS.md — CircleLink AI behavior rules

Rules for AI agents working in this repo. Keep changes small, accurate, and junior-friendly.

Related memory: [PROJECT.md](PROJECT.md) · [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) · [DECISIONS.md](DECISIONS.md)

---

## Before you code

1. **Analyze first** — understand the problem, propose architecture / boundaries, wait for approval on non-trivial work.
2. **Do not implement the whole app or a full redesign in one shot** — small increments only.
3. **UI work:** read root [`DESIGN.md`](../../DESIGN.md) first (especially §0). Summary: [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).
4. **UI redesign screens:** when the local Stitch export exists, open the matching `screen.png` (and `code.html` if needed) under `stitch_circlelink_visual_redesign_brief/`. Also follow `.cursor/rules/ui-redisign-design-source.mdc` when that rule exists.
5. **Git branch:** obey the user's branch instruction. If none is given, confirm before creating or switching branches. The current visual-redesign integration line is `ui-redisign`; see [DECISIONS.md](DECISIONS.md).

---

## Coding workflow

| Rule | Why |
|------|-----|
| Prefer **plan → approve → implement** | Avoids wrong architecture and wasted UI passes |
| **Small increments** | Easier review and rollback |
| Match existing **MVVM + Repository** patterns | See [PROJECT.md](PROJECT.md) and root `ARCHITECTURE.md` |
| **No UseCase layer** unless product direction changes | MVP ViewModels call repositories directly |
| Inject via `AppDependencies` | No `Firestore.firestore()` / Keychain in Views |
| Domain stays pure (`Foundation` only) | No Firebase / UIKit / SwiftUI in Domain |
| `@MainActor` ViewModels; cancel work on disappear | Thread safety + no leaked listeners |
| Explain code you introduce (especially new patterns) | Junior-friendly mentoring |

### Data flow (always keep this shape)

```
User action → View → ViewModel → Repository → Network/Storage
  → Response → ViewModel state → UI update
```

There is **no UseCase layer** in this MVP.

---

## UI / design rules

- **Source of truth:** root `DESIGN.md` (Sunset Parchment). `docs/ai/DESIGN_SYSTEM.md` is a short memory aid — do not invent a second system.
- Tokens live in Swift as `CLColor` / `CLSpacing` / `CLRadius` / `CLTheme` under `CircleLink/Shared/Design/`.
- Adapt Stitch layout to existing CircleLink architecture — **do not paste HTML as-is**.
- Avatars are **squircles everywhere, including Chats**. The intentional circle exception is Connect's Pass / Say Hi / Back action row.
- Soft CTA (`accentSoft` + ink) is default; solid clay is rare (FAB, Say Hi, unread accents).
- `screenHorizontal` = **20** everywhere.
- Navigation roots: system large for Communities/Profile, inline for Connect, and a static
  ink content header for Chats. A custom principal title is allowed only in a chat thread
  because it is an info control.
- Light-first; no purple brand accent; no neon/glow.

---

## Git & commits

- **Do not commit unless the user explicitly asks.**
- **Do not push** unless asked.
- Never update git config, never `--force` push to main/master, never skip hooks unless asked.
- Prefer keep over destructive delete of docs/code you are unsure about.

---

## Security & privacy

- **Do not look inside `.env`.**
- Do not commit secrets (`GoogleService-Info.plist`, `SupabaseSecrets.plist`, credentials). Use `*.example` files as templates.
- Stay on Firebase **Spark** guidance in README: do not treat `functions/` as the active push path (push worker is `websocket-server/`).
- Never describe chat as E2EE: current message text/previews are plaintext Firestore fields;
  TLS protects transport only. Supabase chat images currently use public URLs.

---

## Communication

- Be direct and concise; clarity over depth.
- Explain only what was asked; call out related risks if important.
- For architecture choices: say **why**, tradeoffs, and why this option fits.
- Challenge bad architectural requests — do not blindly comply.
- After generating code: do a short review (architecture, readability, concurrency, edge cases, performance).

---

## Out of scope habits

- Do not generate large speculative abstractions (extra protocols/generics “just in case”).
- Do not rewrite unrelated screens while fixing one screen.
- Do not replace intentional design exceptions for aesthetic uniformity.
- Docs-only tasks: do not sneak in feature code (and vice versa).

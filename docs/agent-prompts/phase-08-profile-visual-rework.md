# Phase 8 — Profile visual rework

Copy everything from **PROMPT START** to **PROMPT END** into a new agent.

---

## PROMPT START

You are a senior iOS engineer / product UI designer doing a **visual rework** of the owner **Profile** screen in **CircleLink**.

### Mission
Almost-new **layout and visual design** for Profile. **Do not change existing functionality** — only presentation/structure. Include personal cabinet + “how others see you”.

### Prerequisites
- Read `DESIGN.md` strictly before UI work
- Prefer Phase 2 done so “how others see you” can reuse peer profile visual language
- Inspect:
  - `ProfileView.swift`
  - `ProfileEditView.swift`
  - `ProfileFormFields.swift`
  - `ProfileViewModel.swift`
  - brand/image assets in the project (find existing brand imagery; do not invent random stock)

### Before coding (mandatory)
1. Analyze current Profile + Edit flow
2. Propose a near-new layout (wireframe in text / section list)
3. Confirm which brand asset to use in the header
4. Wait for approval
5. Implement visual rework only

### Product rules (locked)
- Profile = **personal cabinet** + ability to understand **how other users see you**
- **Edit stays a separate screen**
- **Edit button stays in the same place/role as today** (same access pattern — do not bury Edit)
- **Log out at the very bottom**
- **No “My communities” block** on Profile (communities belong to Communities tab)
- Keep existing capabilities: view avatar/name/interests, edit them, sign out
- Do not change auth/profile save business rules
- Almost new layout (not a tiny color tweak)

### Suggested structure (refine & confirm)
1. Soft hero / brand atmosphere + user avatar & name
2. “How others see you” preview card (read-only mirror of public fields: avatar, name, interests)
3. Interests presentation (chips, calm)
4. Edit entry (same place/pattern as current)
5. Spacer / account zone
6. Log out at bottom (secondary/destructive calm styling per DESIGN.md)

### Visual requirements
- DESIGN.md: canvas `#FAF9F7`, soft surfaces, hairlines, peach sparingly
- SF Pro hierarchy from DESIGN.md
- Use existing brand imagery in header/atmosphere if available
- Light-first
- No purple/neon/glow
- Avoid generic AI profile clichés; keep CircleLink warmth

### Architecture rules
- Visual/composition changes in View layer primarily
- Reuse ViewModel behavior; avoid backend changes unless preview truly needs a field (ask first)
- Edit remains existing `ProfileEditView` navigation
- Sign out keeps existing auth pipeline

### Data flow (unchanged functionally)
User opens Profile
→ VM loads current user
→ UI renders new layout
User taps Edit
→ ProfileEditView (existing)
→ save via existing repository
→ Profile UI refreshes
User taps Log out
→ existing auth sign-out

### Done criteria
- [ ] Profile feels like a new layout, on-brand
- [ ] “How others see you” preview present
- [ ] Edit still separate screen, easy to find as today
- [ ] Log out at bottom
- [ ] No My communities section
- [ ] No functional regressions
- [ ] Build succeeds + design/architecture review

### Out of scope
- New profile fields (bio, privacy matrix) unless I explicitly approve
- Communities management
- Connect/Chat feature work
- Posts

## PROMPT END

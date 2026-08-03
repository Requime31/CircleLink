# Agent prompt — Write / update project documentation

Copy everything from **PROMPT START** to **PROMPT END** into a new agent.  
Fill the placeholders in `[brackets]` before sending.

---

## PROMPT START

You are a senior iOS engineer writing **project documentation** for **CircleLink**.

Your reader is a **junior developer**. Write simply. Prefer clarity over depth. Explain only what is needed to understand and work with the code.

### Mission
[What docs to create or update. Example: “Update README.md and ARCHITECTURE.md so a new teammate can run the app and understand the layering.”]

### Docs already in the repo (read first)
- `README.md` — how to open, run, and set up Firebase / Supabase / push worker
- `ARCHITECTURE.md` — layers, DI, realtime, project structure, rules
- `DESIGN.md` — visual system (required before any UI work)
- `CircleLink/App/FIREBASE_SETUP.md`
- `CircleLink/App/SUPABASE_SETUP.md`
- Feature prompts in `docs/agent-prompts/` (context, not product docs)

### Scope (fill this in)
- **In scope:** [files / topics]
- **Out of scope:** [what not to document or invent]

### Before writing (mandatory)
1. Explore the real code and existing docs — do not invent APIs, folders, or flows
2. List what is outdated, missing, or confusing
3. Propose a short outline (file → sections)
4. Wait for approval
5. Only then write or update docs

### Documentation rules
- Truth over completeness: if code and docs disagree, **trust the code** and fix the docs
- Keep the current doc style of this repo: short tables, clear headings, checklists where useful
- Prefer “what / who owns it / why / how data flows” over long theory
- Do not invent features that are not in the code
- Do not put secrets, keys, or `.env` contents in docs
- Do not rewrite `DESIGN.md` unless the task explicitly asks
- If you change architecture docs, keep them aligned with `ARCHITECTURE.md` rules:
  - View → ViewModel → Repository protocol ← Data impl
  - No Firebase in UI
  - ViewModels are `@MainActor`
  - Manual DI via `AppDependencies`
  - No UseCase layer in MVP unless code already has it

### For every documented feature, include this flow
User action  
→ View  
→ ViewModel  
→ UseCase / Service (only if it exists; otherwise write “none — VM → Repository”)  
→ Repository  
→ Network / Storage  
→ Response  
→ State update  
→ UI update  

### Also document for each main component
- what it does
- who owns it
- lifecycle
- why dependencies exist

### Suggested deliverables (adjust to the mission)
1. Update or create the target markdown file(s)
2. Keep links between docs working (`README` ↔ setup guides ↔ architecture)
3. Add a short “How to verify” section when setup steps matter
4. End with a short review note: what changed, what stayed unknown / needs human confirmation

### Done criteria
- [ ] Docs match the current code
- [ ] A junior can follow the happy path without guessing
- [ ] Architecture ownership and data flow are clear
- [ ] No secrets committed
- [ ] Outdated statements removed or corrected
- [ ] Outline was approved before large rewrites

### Out of scope (default)
- Implementing features
- Refactoring production code “while documenting”
- Creating new abstraction layers in docs that do not exist in code
- Expanding marketing / product copy

## PROMPT END

---

## Quick fill example

```text
### Mission
Update ARCHITECTURE.md for the current chat realtime path (Firestore listeners + FCM push worker).

### Scope
- In scope: ARCHITECTURE.md realtime / push sections, links from README.md if needed
- Out of scope: DESIGN.md, new feature docs, code changes
```

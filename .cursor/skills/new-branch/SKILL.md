---
name: new-branch
description: Create a local git branch for one CircleLink feature before writing code. Use when starting a feature, bugfix, or docs change, or when the user asks for a new branch.
---

# New branch

Always create a **new local branch** before implementing. Do not commit feature work on `main`.

## Branch name

```
feature/<short-name>
```

- lowercase, hyphens, short (`feature/chat-mute`, `feature/firestore-rules-docs`)
- one concern per branch
- do not reuse cloud-agent `cursor/...` names unless you are that cloud agent

```bash
git checkout main
git pull origin main
git checkout -b feature/<short-name>
```

Then implement only that concern.

## Do not

- commit secrets (`GoogleService-Info.plist`, `SupabaseSecrets.plist`, `.env`)
- mix unrelated features on one branch

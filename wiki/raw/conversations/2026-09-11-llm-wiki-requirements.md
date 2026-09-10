---
title: CircleLink LLM Wiki Requirements Discussion
type: source
status: immutable
date: 2026-09-11
tags: [source, conversation, llm-wiki, process]
origin: conversation
---

# CircleLink LLM Wiki Requirements Discussion

This is a curated English rendering of explicit decisions from the Russian-language discussion.
It is not a full transcript.

## Accepted requirements

- The wiki covers CircleLink only.
- Wiki content, filenames, metadata, and logs are entirely in English; agent conversation with the
  owner remains in Russian.
- Wiki maintenance is automatic after material decisions.
- All project knowledge moves into `/wiki`; legacy documents become temporary redirects.
- `/wiki` is a standalone Obsidian vault without depending on Obsidian-specific syntax or runtime.
- Raw storage contains only sources that directly influenced a decision.
- Atomic ADRs preserve decisions while living pages describe current synthesis.
- Historical bootstrap must deeply inspect existing documentation and Git history without
  inventing old rationale.
- Root `AGENTS.md` is a minimal router; `wiki/AGENTS.md` owns the full schema.
- A user-requested and implemented change may become canonical automatically. Agent inferences
  remain proposed or observed until confirmed.
- Every content page is traceable to evidence. Portable relative Markdown links are required.
- Minimal YAML frontmatter is required.
- A dependency-free JavaScript lint runs locally and in GitHub Actions.
- Pull requests use Wiki Lint and a Wiki Impact Gate; `wiki-not-required` records reviewed
  exceptions.
- GitHub Issues track tasks and bugs, one GitHub Project tracks flow, and Milestones track releases.
- The active integration branch is named `integration`; `develop` is the stabilized release
  candidate branch and `main` is production.
- Wiki and code changes belong in the same branch and commit or pull request.
- Sensitive configuration and real user information are prohibited.
- Legacy redirects are removed after the first production release containing the wiki.
- External sources are summarized with provenance and short necessary quotations rather than
  copied wholesale without an appropriate license.

## Related current decision

The owner also explicitly requested that shared profile images use aspect-fit rendering on the
active integration branch so original proportions remain visible.

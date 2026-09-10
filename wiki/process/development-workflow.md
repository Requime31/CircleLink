---
title: Development Workflow
type: process
status: current
updated: 2026-09-11
tags: [process, git, github, releases, wiki]
---

# Development Workflow

## Branch flow

```text
codex/*, feature/*, fix/*
          ↓ pull request
      integration
          ↓ stabilization pull request
        develop
          ↓ release pull request
          main
```

`integration` receives daily completed work. `develop` holds a stabilized release candidate.
`main` holds production release state. Feature work does not commit directly to `develop` or
`main`. A hotfix starts from `main` and is subsequently reconciled into `develop` and
`integration`.

## Work tracking

- GitHub Issues are the source of truth for tasks, bugs, research, and feature requests.
- GitHub Project `CircleLink Development` tracks `Backlog`, `Ready`, `In progress`, `Review`, and
  `Done`.
- Milestones group Issues and pull requests by target release such as `v1.0`.
- The wiki stores durable reasoning and decisions, not live task status.

## Wiki gate

Material decisions update an ADR, affected living pages, `index.md`, and `log.md` in the same
branch and commit as code. Pull requests pass Wiki Lint and Wiki Impact Gate. A reviewed PR with no
durable knowledge impact uses `wiki-not-required`.

Legacy documentation redirects remain until the first production release containing the wiki.
After inbound-link verification, a new decision records their removal.

## Related decisions

- [Branching and release flow](../decisions/process/branching-and-release-flow.md)
- [Repository-local LLM Wiki](../decisions/process/repository-local-llm-wiki.md)

## Sources

- [Curated wiki requirements](../raw/conversations/2026-09-11-llm-wiki-requirements.md).
- Current repository branches and Git history at bootstrap.

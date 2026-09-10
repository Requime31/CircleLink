---
id: adr-process-repository-local-llm-wiki
title: Repository-Local LLM Wiki
type: decision
status: implemented
date: 2026-09-11
tags: [process, documentation, llm-wiki, obsidian]
sources:
  - ../../raw/external/karpathy-llm-wiki.md
  - ../../raw/conversations/2026-09-11-llm-wiki-requirements.md
---

# Repository-Local LLM Wiki

## Context

Project decisions and rationale were split between chats, code, Git history, and several Markdown
documents. Future agents could see current code but repeatedly had to reconstruct why it existed.

## Decision

Maintain all CircleLink knowledge in `/wiki`, a repository-local Obsidian-compatible Markdown
vault. Immutable curated sources feed atomic ADRs and living synthesis pages. A minimal root
`AGENTS.md` routes every agent to the full schema in `wiki/AGENTS.md`.

Maintenance is automatic for material decisions. User requests may become accepted decisions;
implemented and validated requests may become implemented decisions. Agent-derived conclusions
remain proposed or observed until confirmed. Wiki and code changes share a branch, commit, or pull
request. Deterministic lint and a pull-request impact gate enforce structure and reviewed coverage.

GitHub Issues and Projects own changing work state. The wiki owns durable context. Legacy documents
remain redirects until the first production release containing the wiki.

## Alternatives considered

- Rely on chat history or retrieval over raw documents: rejected because synthesis would be
  rebuilt repeatedly and decisions would not compound.
- Keep canonical documents outside `/wiki`: rejected because it creates competing sources of truth.
- Store the vault outside the repository: rejected because code and knowledge would lose shared
  versioning and branch review.

## Consequences

Every material change carries a small documentation obligation. In return, new sessions get a
navigable current model, historical rationale, explicit uncertainty, and traceability to evidence.

## Sources

- [Karpathy LLM Wiki pattern](../../raw/external/karpathy-llm-wiki.md)
- [Curated CircleLink requirements](../../raw/conversations/2026-09-11-llm-wiki-requirements.md)
- [Development workflow](../../process/development-workflow.md)

---
title: Karpathy LLM Wiki Pattern
type: source
status: immutable
date: 2026-09-11
tags: [source, llm-wiki, knowledge-management]
origin: external
---

# Karpathy LLM Wiki Pattern

- Author: Andrej Karpathy
- Original: [LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- Retrieved: 2026-09-10

## Relevant ideas

The source proposes a persistent, LLM-maintained Markdown wiki between immutable raw sources and
the user. New sources are synthesized once into linked pages instead of being rediscovered on
every query. A schema file governs ingestion, queries, indexing, logging, and maintenance.

The pattern separates immutable raw sources, an agent-owned wiki, and instructions that define
the system. It recommends a content index, an append-only operation log, incremental ingestion,
cross-references, and periodic checks for contradictions, stale claims, missing concepts, and
orphan pages. The exact directory layout and tooling are intentionally left to each project.

## Influence on CircleLink

CircleLink adopts the three-layer model, Markdown storage, automatic agent maintenance, an index,
an append-only log, immutable curated sources, and linting. It adds decision governance, atomic
ADR records, living synthesis pages, GitHub workflow gates, privacy rules, and same-commit coupling
between decisions and implementation.

This record summarizes the source and does not reproduce the full copyrighted text.

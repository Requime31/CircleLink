# CircleLink LLM Wiki Schema

This directory is CircleLink's only canonical documentation and knowledge base. It is an
Obsidian-compatible Markdown vault, but it must remain usable through GitHub, `rg`, and any
LLM agent without Obsidian.

## Ownership and authority

- Humans own product, UX, and architecture decisions.
- Merged code proves implemented behavior.
- The agent owns organization, cross-references, indexing, synthesis, and maintenance.
- A user-requested decision may be recorded as `accepted`; after implementation and validation
  it becomes `implemented`.
- Agent conclusions are `proposed`, or observations on a living page, until a human accepts them.
- Never silently promote an observation or proposal to an accepted decision.
- When code, a contract, and the wiki disagree, describe the conflict. Do not invent intent.

## Layers

1. `raw/` contains immutable, curated sources that directly influenced decisions.
2. Living pages under `product/`, `architecture/`, `backend/`, `design/`, `engineering/`,
   `operations/`, `process/`, and `quality/` describe the current synthesis.
3. `decisions/<domain>/` contains atomic decision records with stable semantic IDs.

Tasks, bugs, sprint state, branch heads, and roadmaps belong in GitHub Issues, Projects, and
Milestones. The wiki may cite an Issue or PR as historical evidence but never copies its live
status.

## Required frontmatter

Every content and source page begins with minimal YAML frontmatter.

Living page:

```yaml
---
title: Connect
type: product
status: current
updated: 2026-09-11
tags: [connect, product]
---
```

Decision:

```yaml
---
id: adr-connect-hybrid-onboarding
title: Connect Hybrid Onboarding
type: decision
status: implemented
date: 2026-09-10
tags: [connect, onboarding, ux]
sources:
  - ../../raw/conversations/2026-09-10-llm-wiki-requirements.md
---
```

Source:

```yaml
---
title: Source title
type: source
status: immutable
date: 2026-09-11
tags: [source]
origin: external
---
```

Allowed decision statuses are `proposed`, `accepted`, `implemented`, `superseded`, and
`rejected`. Living pages use `current` or `historical`. Sources use `immutable`.

Decision files use `decisions/<domain>/<stable-semantic-slug>.md`. Never rename an accepted
decision merely to improve wording. A replacement decision links to the old one and marks it
`superseded`; decisions are never deleted.

## Links and evidence

- Use portable relative Markdown links, not Obsidian wikilinks.
- Link to code by stable repository path and symbol name; avoid line numbers.
- Record a commit SHA only for a historical claim tied to that exact commit.
- Every content page except `index.md` and `log.md` must be linked from `index.md` with a short
  description.
- Every factual decision names its evidence in `sources` and explains it in a `Sources` section.
- Do not copy changing values such as current branch heads, file counts, or open-task counts.

## Workflows

### Ingest

1. Add one curated immutable source under `raw/`.
2. Extract claims and distinguish explicit decisions from observations.
3. Create or update atomic ADRs.
4. Update all affected living pages and cross-references.
5. Update `index.md` and append one entry to `log.md`.
6. Run `node wiki/tools/lint-wiki.js`.

External sources store URL, author, retrieval date, a summary, and only short necessary quotes.
Do not copy full copyrighted works without a license that permits it. Conversation sources keep
only decision-bearing excerpts, not full transcripts or tool chatter.

### Query and write-back

Read `index.md` first, then relevant pages and their sources. Write durable findings back only
when they establish a reusable system cause, constraint, policy, or accepted decision. One-off
commands and routine fixes do not belong in the wiki.

### Lint

Run the mechanical lint after every wiki edit. Perform semantic LLM lint after a large ingest,
an architectural change, before promotion from `integration` to `develop`, before release from
`develop` to `main`, or when explicitly requested. Semantic lint reports contradictions and
unsupported claims; it does not silently rewrite canonical decisions.

## Privacy

Never store secrets, credentials, tokens, certificates, private plist contents, production user
data, real chats, email addresses, FCM tokens, or account IDs. Sanitize screenshots. Do not copy
a discovered secret into a warning; name only its file and category.

## Legacy redirects

The old documentation paths are temporary redirects. Remove them after the first production
release that includes this wiki, once all inbound links are verified. Keep root `README.md` and
root `AGENTS.md` as permanent entry points.

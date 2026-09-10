# CircleLink Agent Router

Before material work, read [`wiki/index.md`](wiki/index.md) and the relevant linked pages.
Follow [`wiki/AGENTS.md`](wiki/AGENTS.md) for knowledge governance and maintenance.

After a material product, UX, architecture, data, backend, security, design, quality, or
workflow decision, update the wiki in the same branch and commit as the related code. Run:

```bash
node wiki/tools/lint-wiki.js
```

Routine formatting, renames, and mechanical fixes do not require a wiki update. Pull requests
without a wiki impact must carry the `wiki-not-required` label.

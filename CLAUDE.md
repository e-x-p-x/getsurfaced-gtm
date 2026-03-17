# GTM Knowledge Base — GetSurfaced

## What This Is
Go-to-market intelligence for GetSurfaced (getsurfaced.ai).
Generated and maintained using GTM Playbook skills from expx-skills.

## Key Files
- `docs/icp.md` — Ideal Customer Profile (start here)
- `docs/battlecards/README.md` — Competitive intelligence index
- `docs/signals/README.md` — Account signal priority board
- `docs/pipeline/scored-leads.md` — Qualified lead pipeline
- `docs/reports/` — Weekly GTM reports

## Running Skills
Run GTM skills from this directory. They read/write to `docs/`.

Cascade order:
1. `/icp-architect` — ICP (run first, everything depends on this)
2. `/competitive-battlecard-generator` — Competitor analysis
3. `/account-research-brief` — Target account research
4. `/signal-scanner` — Buying signal detection
5. `/qualification-scorer` — Lead scoring and pipeline
6. `/outreach-sequence-builder` — Multi-channel outreach
7. `/meeting-prep-brief` — Pre-call intelligence (run before meetings)
8. `/weekly-gtm-report` — Run every Friday
9. `/crm-hygiene-scanner` — CRM data quality audit
10. `/agent-architecture-planner` — Automate GTM workflows

## Product Repo
The product codebase is at `~/Dev/content-studio/`. That repo's CLAUDE.md points back here for GTM context.

## For AI Tools
All files are self-contained markdown with structured headings and tables.
Cross-references use relative paths within `docs/`.

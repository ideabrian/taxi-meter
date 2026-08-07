# Billing Features — What Exists, Where

## taxi-meter (this repo)

Eye candy. Statusline module that shows elapsed time and a running fare.
No invoices, no audit trail, no start/stop controls, no configuration UI.
Hardcoded $150/hr. Display-only.

Files: `install.sh`, `statusline.sh`, `README.md`

## try-business (../try-business)

Where the actual billing machinery lives.

### Session Timer
- `.claude/hooks/session-start.sh` — starts/resets per-session timer
- `.claude/hooks/stop.sh` — stop hook
- `.claude/sessions/*.json` — per-session state (start timestamp, completions list)

### Invoice Generation
- `factory/invoice.mjs` — generates per-iteration invoices
- `./try invoice` — CLI command
- `factory/invoices/TB-*.md` — 40+ invoices generated to date
- Tracks: iteration #, description, duration, amount, rate, date, session ID, progress

### Auditor (CF Worker)
- `auditor/src/index.js` — Hono + D1 Cloudflare Worker
- Web UI: stats dashboard, invoice table, session drill-down
- API: `/api/invoices`, `/api/sessions`, `/api/sessions/:id`, `/api/seed`
- Mobile-responsive, dark theme
- D1 tables: `invoices`, `sessions`

### After Action Reports (AAR)
- `factory/report.mjs` — generates per-iteration AARs
- `factory/aars/0042.md` through `factory/aars/0077.md`
- Captures: iteration, track, description, progress, file count, duration

### Lock Ceremony (ties it all together)
- `factory/lock.sh` — test, spec, commit, AAR, invoice in one command
- `./try lock "description"` — CLI entry point
- Appends completion to session timer
- Calculates elapsed time from session start
- Commits everything atomically

## Gap

taxi-meter is the open-source display layer.
try-business has the billing engine but isn't portable — it's wired into the factory iteration system.
A standalone billing tool would need to extract: session tracking, configurable rates, invoice generation, and the auditor — without the factory dependency.

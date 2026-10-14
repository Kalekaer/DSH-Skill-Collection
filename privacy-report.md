# Privacy Report

This repository ships **demo data only**. It contains no personal data, no user
history, and no local paths.

## Data included

- Demo data only (15 well-known public repositories)
- Public metadata: project name, description, stars, license, first/last seen
- Chinese human-readable layer for the demo projects (written for the demo)
- Rule files: taxonomy, plan definitions, synonym groups

## Data excluded

- Personal project library and personal notes
- User history and behaviour logs (recommend log, status log, events history)
- User workspaces
- Local paths and machine/user names (replaced with placeholders)
- API keys, tokens, cookies, credentials
- Logs, caches, editor settings, temporary files
- The personal recommendation table (.univer); the bundled self-check reports it as missing on purpose

## Runtime

- Local only
- No automatic upload
- No data collection
- No telemetry
- The single-file page (`overview.html`) performs no network requests

## Verification

| Check | Result |
|---|---|
| Local paths (`<你的工作区>` placeholder used instead) | 0 hits |
| Machine / user name (replaced with `<你的用户名>`) | 0 hits |
| Email addresses, phone numbers | 0 hits |
| Real tokens / API keys / cookies | none (the only matches are the project's own leak-detection patterns and unrelated English words) |
| User workspace file | empty |
| User notes file | empty |
| Demo projects flagged as "added by user" | 0 |
| Demo projects carrying personal notes | 0 |
| Logs / temp / cache / editor config | none present |

Checked before packaging. Re-run any time with the bundled self-checks:

- `audit.ps1` — data and rule invariants
- `check-page.ps1` — the generated page actually works
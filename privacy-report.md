# Privacy Report

This repository ships **demo data only**. It contains no personal data, no user
history, and no local paths.

## Data included

- Demo data only (15 well-known public repositories, 5 of them picked for the demo day)
- Public metadata: project name, description, stars, license, first/last seen
- Chinese human-readable layer for the demo projects (written for the demo)
- Rule files: taxonomy, plan definitions, synonym groups, schema / criteria
- Pre-generated site pages (`index.html` + `data/site/`, built from the demo data)

## Data excluded

- Personal project library and personal notes (`note` / `user_notes` are empty strings)
- User history and behaviour logs (real recommend log, status log, run history)
- User workspaces (empty stub file)
- Local paths and machine/user names (0 hits — verified with the scan below)
- API keys, tokens, cookies, credentials
- Logs, caches, editor settings, temporary files, Python venvs / model caches
- The personal recommendation table (.univer); the bundled self-check reports it as missing on purpose

## Runtime

- Local only
- No automatic upload
- No data collection
- No telemetry
- The site pages perform no network requests; fonts and images are local (`assets/`)

## Verification

| Check | Result |
|---|---|
| Local paths (`<你的工作区>...`) | 0 hits |
| Machine / user name (`<用户目录>\...`, hostname) | 0 hits |
| Email addresses, phone numbers | 0 hits |
| Real tokens / API keys / cookies | none |
| Personal `subscriptions` list in `config.json` | not shipped — the neutral 6-repo demo list is used |
| User workspace file | empty |
| User notes file | empty |
| Demo projects flagged as "added by user" | 0 |
| Demo projects carrying personal notes | 0 |
| Logs / temp / cache / editor config | none present |

Checked before packaging (2026-10-19). Re-run any time with the bundled self-checks:

- `audit.ps1` — 166 invariants (data, rules AND the generated site pages)
- `check-config.ps1` — config + status round-trip

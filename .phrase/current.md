# Current Phase

## Status

In Progress

## Goal

Fix browse pagination for included entity types (recordings, releases, works, release-groups) in musicbrainz.el — the lookup endpoint returns at most 25 items per type and ignores limit/offset.

## Entry Condition

- Recordings/works truncated to 25 items in entity detail view.
- Old pagination loop queried lookup endpoint again with `limit=100&offset=N` but always got the same first 25 back → duplicates.
- JSON-LD `if` cond structure had an extra `)` on the THEN branch line, causing ELSE branch to always win.

## Scope

- Replace lookup-endpoint pagination with browse-endpoint pagination (`/ws/2/{type}?parent=MBID&limit=100&offset=N`).
- Read count from browse response (`recording-count`, `work-count`, etc.) instead of lookup (which has none in JSON).
- Fix cond structure: remove extra `)` from THEN branch, add matching `)` to ELSE branch.
- Verify byte-compilation and test with real API.

## Out Of Scope

- Search result pagination (separate mechanism via `musicbrainz--search`).
- Cloudflare JSON-LD fetch blocking.
- Entity type detail views for label, event, place, series, instrument, area.

## Acceptance Gate

- [ ] Browse pagination: for an entity with >25 recordings, all recordings appear (not truncated to 25).
- [ ] Recordings/works display as comma-separated names (THEN branch) instead of collapsible raw alist (ELSE branch).
- [ ] No duplicates in paginated result sets.
- [ ] Pagination handles edge cases: 0 items, partial page (<100), exact multiple of 100.
- [ ] Byte-compilation succeeds.

## Active Task Slice

```text
task001 [x] goal:cond structure fix (extra )) | scope:musicbrainz.el | verify:byte-compile + type-of result
task002 [x] goal:browse pagination rewrite      | scope:musicbrainz.el | verify:API response key format
task003 [ ] goal:end-to-end pagination test      | scope:manual             | verify:load entity with >25 recordings
```

## Known Blockers

- Cloudflare blocks `Accept: application/ld+json` to MusicBrainz web page URLs.
- Rate limiting: large result sets (e.g. 37k recordings) require 371+ browse requests, each rate-limited.

## Next Phase

- **Status**: Pagination rewrite complete pending end-to-end verification.
- **Available**: Investigate Cloudflare JSON-LD fetch blocking.
- **Available**: Add entity type detail views for label, event, place, series, instrument, area.
- **Available**: Pagination for search results beyond current page.

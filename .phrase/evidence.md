# Evidence

Record only evidence that can change future planning or durable decisions.

### 2026-05-18: Unicode garbled text fix (UTF-8 decode in API & JSON-LD)

**Observation**:

- `url-retrieve-synchronously` returns a unibyte buffer with raw UTF-8 bytes.
- `json-read` on undecoded bytes stores multi-byte UTF-8 sequences as individual Latin-1 characters (e.g. `â` for U+2019).
- Both `musicbrainz--api-request` and `musicbrainz--fetch-json-ld` affected.
- Nested sub-entity fields (works, recordings) displayed garbled text.

**Interpretation**:

- The Emacs URL library does not guarantee decoded UTF-8 in the response buffer.
- Explicit `set-buffer-multibyte t` + `(decode-coding-region (point) (point-max) 'utf-8)` is required before `json-read`.
- This is not specific to MusicBrainz — any API client using `url-retrieve-synchronously` with UTF-8 JSON responses needs the same fix.

**Verification**:

- Added `(set-buffer-multibyte t)` and `(decode-coding-region ... 'utf-8)` in both `musicbrainz--api-request` (after header skip) and `musicbrainz--fetch-json-ld` (after `url-insert-file-contents`).
- User confirmed garbled text no longer appears ("没有出现问题").
- Byte-compilation succeeds (only pre-existing warnings).

**Remaining Blockers**:

- `musicbrainz-entity-view` `:on-mount` async race (timer fires before user action completes).
- Cloudflare blocks `Accept: application/ld+json` to MusicBrainz web page URLs.

**Recommended Next Action**:

- Close current phase after updating `current.md` and `roadmap.md`.
- Next phase: fix async race in `:on-mount` timer and broken "Retry" button.

### 2026-05-18: Browse pagination fix — lookup endpoint has no count & ignores limit/offset

**Observation**:

- `musicbrainz--json-ld-fields` clause 2 (`if (and (consp (caar v)) (consp (cdar v)))`) always took the
  ELSE branch due to an extra `)` on the THEN branch line that prematurely closed the `if` form.
- Extra `)` made the ELSE `(let ...)` a separate cond clause body form; cond returns the last body
  form's value, so ELSE always won regardless of condition.
- Fixed: line 587 `)))))` → `))))` (removed 1 `)`); line 604 `))))))))` → `)))))))))` (added 1 `)` to
  close outer if + cond clause). Verified: recordings now return `vui-vnode-hstack` (comma-separated
  names) instead of `vui-vnode-component` (collapsible raw alist).

**Interpretation**:

- The extra `)` was introduced during the `vui-collapsible` refactoring (one nesting level added to
  ELSE branch but paren mistakenly also added to THEN branch).
- The if-else structure needs the THEN branch to close with 4 `)` (mapconcat, meta, list, let*) and
  the ELSE branch to close with 8 `)` (mapcar, delq, apply, collapsible, list, inner-if, let, outer-if).

**Verification**:

- `(type-of result[0])` = `vui-vnode-hstack` (previously `vui-vnode-component`) ✓
- Byte-compilation succeeds without "Malformed function" warnings ✓

---

### 2026-05-18: Browse pagination fix — lookup endpoint has no count & ignores limit/offset

**Observation**:

- MusicBrainz lookup endpoint (`/ws/2/{type}/{MBID}?inc=...`) returns at most **25 items** per
  included entity type (hardcoded `$MAX_ITEMS => 25` in each WS/2 controller).
- The response **does not include `-count` fields** in JSON format (verified via curl against
  `/ws/2/artist/b10bbbfc...?inc=recordings+works&fmt=json` — no `recordings-count` or `works-count`
  in top-level keys).
- `limit`/`offset` URL parameters are **not recognized** on lookup endpoints (the `ws_defs` for
  lookups only list `optional => [ qw(fmt) ]`).
- Old pagination code queried the lookup endpoint with `limit=100&offset=N` and always got the same
  first 25 items back — resulting in duplicates.
- Browse endpoints (`/ws/2/recording?artist=MBID&limit=100`) DO support `limit`/`offset` AND return
  count metadata (`recording-count`, `work-count`, `release-group-count`, etc.).

**Verification** (annotated API responses, 2026-05-18):

| Endpoint | Count key | Total (Beatles) | Items key |
|---|---|---|---|
| `/ws/2/recording?artist=b10...` | `recording-count` | 37147 | `recordings` |
| `/ws/2/work?artist=b10...` | `work-count` | 616 | `works` |
| `/ws/2/release-group?artist=b10...` | `release-group-count` | 1016 | `release-groups` |

- Code now reads `(alist-get (intern (format "%s-count" browse-type)) page)` for total.
- Pagination loop uses browse with `limit=100&offset=N`, stops when all items fetched or page < 100 items.
- Source file: `/home/iris/.config/emacs/elpaca/sources/BrainzWrap/musicbrainz.el` lines 166-204.

**Server source** (for reference):

- `$MAX_ITEMS => 25` in each WS/2 controller
  (`Artist.pm:46`, `Recording.pm:58`, `Release.pm:65`, `ReleaseGroup.pm:47`, etc.).
- Lookup `ws_defs` have `optional => [ qw(fmt) ]` — no `limit` or `offset`.
- Browse uses `_limit_and_offset` (ControllerBase/WS/2.pm:288) — default 25, max 100.

**Recommended Next Action**:

- Consider adding `work` and `recording` entity types to `musicbrainz--load-entity-async` inc list if
  they need pagination too (currently not included in any inc list).
- The Cloudflare JSON-LD fetch blocking remains unaddressed — may be environmental.

---

### 2026-05-18: Search pagination — auto-fetch up to 300 results

**Observation**:

- `musicbrainz-page-size` defaulted to 25; search only returned 25 items per query.
- API search endpoint supports `limit=100&offset=N` and returns `count` (total matches).
- For "sony" search: `count: 357` total, but only 25 returned.
- UI `page-size` of 15 allowed 1 page of 15 items + 1 page of 10 items = only 25 total.

**Changes**:

- `musicbrainz-page-size` default: 25 → 100.
- `musicbrainz--do-search` now reads `count` from first API response; if total > fetched,
  auto-fetches subsequent pages (limit=100, offset incremental) up to
  `musicbrainz-max-search-items` (300).
- `musicbrainz-search-input` state: added `total-count`.
- `musicbrainz-results` component: accepts `:total-count` prop; header shows
  "Found 300/357 result(s)" when total exceeds fetched count.

**Verification**:

- Byte-compilation succeeds (only pre-existing docstring width warnings).
- API endpoint verified:
  `/ws/2/artist?query=sony&limit=100&offset=0` returns `artists`: 100 items, `count`: 357.
- Every entity type (artist, release, recording, etc.) uses the same search endpoint format.

**Remaining**:

- For queries with >300 results, user still sees capped count. Could add a "Load more" button
  in a future phase.

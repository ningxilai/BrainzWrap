# Roadmap

## Goal

Keep long-term direction visible at phase granularity while letting short-term
implementation follow evidence.

## Planning Rule

Roadmap entries describe phase direction, entry conditions, acceptance gates,
and major out-of-scope boundaries. Detailed implementation tasks belong only in
`.phrase/current.md`.

## Phases

### Phase 1: Establish Current Context

**Status**: Complete

**Goal**: Convert the active work into a minimal current phase brief.

**Acceptance Gate**:

- `.phrase/current.md` describes the active phase.
- Any relevant existing evidence is summarized in `.phrase/evidence.md`.
- Stale historical context is moved or linked from `.phrase/archive/`.

### Phase 2: Fix Unicode garbled text + collapsible nested data

**Status**: Complete

**Goal**: Add explicit UTF-8 decoding to both API and JSON-LD response paths; replace flat nested-data previews with `vui-collapsible` components.

**Entry Condition**: Garbled `â` characters in works/recordings; flat `[N items]: preview...` text.

**Acceptance Gate**:

- [x] User confirms garbled text fixed.
- [x] `decode-coding-region` + `set-buffer-multibyte` applied to both read paths.
- [x] Nested data uses collapsible sections.
- [x] Byte-compilation clean.

### Phase 3: Fix async race in entity view :on-mount + Retry button

**Status**: Complete

**Goal**: Extract async load logic into reusable `musicbrainz--load-entity-async`; fix "Retry" button stuck on loading; protect against stale timer callbacks.

**Entry Condition**: Phase 2 complete; Retry button broken.

**Acceptance Gate**:

- [x] `musicbrainz--load-entity-async` extracted, returns timer, takes `on-success`/`on-error` callbacks.
- [x] `:on-mount` uses extracted function with `vui-async-callback` wrappers.
- [x] "Retry" button calls extracted function instead of just setting state.
- [x] Cleanup uses `(when (timerp timer) (cancel-timer timer))` for safety.
- [x] Byte-compilation clean.

### Phase 4: Fix browse pagination for included entity types

**Status**: In Progress

**Goal**: MusicBrainz lookup endpoint returns at most 25 items per included type and ignores `limit`/`offset`. Replace with browse-endpoint pagination (`/ws/2/{type}?parent=MBID&limit=100&offset=N`) that reads `{type}-count` to know the total. Also fix the `if` cond structure in `musicbrainz--json-ld-fields` where an extra `)` on the THEN branch line caused the ELSE branch to always win.

**Entry Condition**: Phase 3 complete; recordings/works display broken (ELSE branch always wins); items truncated to 25.

**Acceptance Gate**:

- [x] Cond structure fix: recordings now return `vui-vnode-hstack` (THEN branch) instead of `vui-vnode-component`.
- [x] Browse pagination replaces lookup pagination for `musicbrainz--paginated-inc-types`.
- [x] Byte-compilation succeeds.
- [ ] End-to-end test: entity with >25 recordings loads all items, no duplicates.

### Phase 5: (Planned) Search result pagination

**Status**: Planned

**Goal**: Add pagination for search results beyond page 1 using the existing `musicbrainz--search` offset/limit params.

# vino-project

Emacs Lisp API clients for MusicBrainz and BookBrainz, sharing the same tech stack (EIEIO entity dispatch, async API requests, Org integration).  The two files evolved separately — `musicbrainz.el` accumulated over time from legacy code, while `bookbrainz.el` was written later with a cleaner structure (VUI interface, `cl-defmethod` dispatch, simpler naming).  Both serve the same purpose: fetch entity data and integrate into an Emacs workflow.

## Modules

| Module | API | Highlights |
|--------|-----|------------|
| `musicbrainz.el` | MusicBrainz | Lazy pagination for releases/recordings/works, `mz-let*` / `mz-when-let*` macros |
| `bookbrainz.el` | BookBrainz | VUI interactive views, `cl-defmethod` dispatch (`bb-detail`, `bb-format-result`), search/lookup |

## Tests

57 unit tests for bookbrainz.el:

```sh
emacs -Q --batch -l tests/test-runner.el -f ert-run-tests-batch-and-exit
```
